import CoreGraphics

/// The editor's mutable layout model: a binary-split tree over the unit square
/// plus a minimum cell size. All mutations are pure — they return a new grid —
/// which makes undo/redo a matter of restoring a previous value.
///
/// The tree guarantees a gap-free, non-overlapping tiling by construction, so
/// the only validation needed anywhere is the `minCellFraction` clamp on
/// resize/split. Flattening (`zones()` / `layout(named:)`) is the stable seam
/// into the existing snap/overlay pipeline, which consumes plain `[Zone]`.
public struct EditableGrid: Equatable, Codable, Sendable {
    public var root: GridNode

    /// The smallest extent any cell may occupy along a split axis, as a fraction
    /// of the whole display. Resizes and splits clamp to keep every cell at least
    /// this large.
    public var minCellFraction: Double

    public init(root: GridNode = .leaf, minCellFraction: Double = 0.05) {
        self.root = root
        self.minCellFraction = minCellFraction
    }

    /// A grid consisting of a single full-display cell.
    public static var single: EditableGrid { EditableGrid() }

    private static let unitSquare = CGRect(x: 0, y: 0, width: 1, height: 1)

    // MARK: - Mutations

    /// Replaces the leaf at `path` with a split of two new leaves. Splitting a
    /// non-leaf (or an out-of-range path) is a no-op. `ratio` is clamped to keep
    /// both halves at least `minCellFraction` wide.
    public func splitting(_ path: GridPath, axis: GridAxis, at ratio: Double = 0.5) -> EditableGrid {
        guard case .leaf = node(at: path) else { return self }
        let split = GridNode.split(axis: axis, ratio: clampRatio(ratio), first: .leaf, second: .leaf)
        return replacingNode(at: path, with: split)
    }

    /// Collapses the split at `path` (and everything beneath it) back into a
    /// single leaf — the inverse of `splitting` for a freshly split cell.
    /// Merging a leaf (or an out-of-range path) is a no-op.
    public func merging(_ path: GridPath) -> EditableGrid {
        guard case .split = node(at: path) else { return self }
        return replacingNode(at: path, with: .leaf)
    }

    /// Merges the leaf at `leafPath` into its sibling by collapsing their shared
    /// parent split. This is a guillotine merge: it only applies when the sibling
    /// is *also* a leaf, so a subdivided neighbour's cells are never silently
    /// destroyed. The root leaf (no sibling) and any non-leaf path are no-ops.
    public func mergingLeaf(at leafPath: GridPath) -> EditableGrid {
        guard case .leaf = node(at: leafPath), let lastIndex = leafPath.indices.last else { return self }
        let parent = GridPath(leafPath.indices.dropLast())
        let sibling = parent.appending(lastIndex == 0 ? 1 : 0)
        guard case .leaf = node(at: sibling) else { return self }
        return merging(parent)
    }

    /// Moves the divider owned by the split at `id` to `ratio`, clamped so neither
    /// side — including any nested cells — falls below `minCellFraction`.
    public func resizingDivider(_ id: GridPath, to ratio: Double) -> EditableGrid {
        guard case let .split(axis, _, first, second) = node(at: id),
              let region = rect(at: id) else { return self }

        let length = axis == .vertical ? region.width : region.height
        guard length > 0 else { return self }

        let firstMin = Self.requiredExtent(first, along: axis, minCell: minCellFraction)
        let secondMin = Self.requiredExtent(second, along: axis, minCell: minCellFraction)
        let lower = firstMin / length
        let upper = 1 - secondMin / length
        // With the default `minCellFraction` and split-time clamping the feasible
        // range is always non-empty; the `lower > upper` branch (region too small
        // to honour both minima) only arises with a large `minCellFraction`, so we
        // settle on the midpoint and keep the result in `[0, 1]`.
        let target = lower <= upper ? min(max(ratio, lower), upper) : (lower + upper) / 2
        let clamped = min(max(target, 0), 1)

        let resized = GridNode.split(axis: axis, ratio: clamped, first: first, second: second)
        return replacingNode(at: id, with: resized)
    }

    // MARK: - Queries

    /// The node at `path`, or `nil` if the path runs off the tree.
    public func node(at path: GridPath) -> GridNode? {
        var current = root
        for index in path.indices {
            guard case let .split(_, _, first, second) = current else { return nil }
            switch index {
            case 0: current = first
            case 1: current = second
            default: return nil
            }
        }
        return current
    }

    /// The unit-square region the node at `path` occupies, or `nil` for an
    /// invalid path.
    public func rect(at path: GridPath) -> CGRect? {
        var region = Self.unitSquare
        var current = root
        for index in path.indices {
            guard case let .split(axis, ratio, first, second) = current else { return nil }
            let (firstRect, secondRect) = Self.subdivide(region, axis: axis, ratio: ratio)
            switch index {
            case 0: region = firstRect; current = first
            case 1: region = secondRect; current = second
            default: return nil
            }
        }
        return region
    }

    /// Paths of every leaf, in depth-first (first-child-first) order.
    public func leafPaths() -> [GridPath] {
        var paths: [GridPath] = []
        func walk(_ node: GridNode, _ path: GridPath) {
            switch node {
            case .leaf:
                paths.append(path)
            case let .split(_, _, first, second):
                walk(first, path.appending(0))
                walk(second, path.appending(1))
            }
        }
        walk(root, .root)
        return paths
    }

    /// The path of the leaf containing `point`, or `nil` if `point` lies outside
    /// the unit square.
    public func leafPath(at point: CGPoint) -> GridPath? {
        guard Self.unitSquare.contains(point) else { return nil }
        var region = Self.unitSquare
        var current = root
        var indices: [Int] = []
        while case let .split(axis, ratio, first, second) = current {
            let (firstRect, secondRect) = Self.subdivide(region, axis: axis, ratio: ratio)
            if firstRect.contains(point) {
                region = firstRect; current = first; indices.append(0)
            } else {
                region = secondRect; current = second; indices.append(1)
            }
        }
        return GridPath(indices)
    }

    /// Every divider in the tree, for the editor to draw and hit-test.
    public func dividers() -> [GridDivider] {
        var dividers: [GridDivider] = []
        func walk(_ node: GridNode, _ path: GridPath, _ region: CGRect) {
            guard case let .split(axis, ratio, first, second) = node else { return }
            let (firstRect, secondRect) = Self.subdivide(region, axis: axis, ratio: ratio)
            dividers.append(
                GridDivider(id: path, axis: axis, ratio: ratio,
                            bounds: Self.dividerLine(region, axis: axis, ratio: ratio))
            )
            walk(first, path.appending(0), firstRect)
            walk(second, path.appending(1), secondRect)
        }
        walk(root, .root, Self.unitSquare)
        return dividers
    }

    // MARK: - Flatten (the seam into the snap/overlay pipeline)

    /// The tree flattened to `[Zone]` with normalized frames. Ids are assigned in
    /// depth-first (first-child-first) order, so the same structure always yields
    /// the same ids.
    public func zones() -> [Zone] {
        var zones: [Zone] = []
        var nextID = 0
        func walk(_ node: GridNode, _ region: CGRect) {
            switch node {
            case .leaf:
                zones.append(Zone(id: nextID, normalizedFrame: region))
                nextID += 1
            case let .split(axis, ratio, first, second):
                let (firstRect, secondRect) = Self.subdivide(region, axis: axis, ratio: ratio)
                walk(first, firstRect)
                walk(second, secondRect)
            }
        }
        walk(root, Self.unitSquare)
        return zones
    }

    /// The flattened grid as a named `ZoneLayout`.
    public func layout(named name: String) -> ZoneLayout {
        ZoneLayout(name: name, zones: zones())
    }

    // MARK: - Private helpers

    private func clampRatio(_ ratio: Double) -> Double {
        min(max(ratio, minCellFraction), 1 - minCellFraction)
    }

    private func replacingNode(at path: GridPath, with newNode: GridNode) -> EditableGrid {
        guard let updated = Self.replacing(root, at: path.indices, with: newNode) else { return self }
        var copy = self
        copy.root = updated
        return copy
    }

    /// Splits `region` into (first, second) at `ratio` along `axis`, in a
    /// top-left coordinate space (y grows down).
    private static func subdivide(_ region: CGRect, axis: GridAxis, ratio: Double) -> (CGRect, CGRect) {
        switch axis {
        case .vertical:
            let width = region.width * ratio
            return (
                CGRect(x: region.minX, y: region.minY, width: width, height: region.height),
                CGRect(x: region.minX + width, y: region.minY, width: region.width - width, height: region.height)
            )
        case .horizontal:
            let height = region.height * ratio
            return (
                CGRect(x: region.minX, y: region.minY, width: region.width, height: height),
                CGRect(x: region.minX, y: region.minY + height, width: region.width, height: region.height - height)
            )
        }
    }

    private static func dividerLine(_ region: CGRect, axis: GridAxis, ratio: Double) -> CGRect {
        switch axis {
        case .vertical:
            let x = region.minX + region.width * ratio
            return CGRect(x: x, y: region.minY, width: 0, height: region.height)
        case .horizontal:
            let y = region.minY + region.height * ratio
            return CGRect(x: region.minX, y: y, width: region.width, height: 0)
        }
    }

    /// The minimum extent `node`'s subtree needs along `axis`, as a fraction of
    /// the whole display: leaves need `minCell`; splits along `axis` add their
    /// children's needs, splits across it take the larger.
    private static func requiredExtent(_ node: GridNode, along axis: GridAxis, minCell: Double) -> Double {
        switch node {
        case .leaf:
            return minCell
        case let .split(splitAxis, _, first, second):
            let firstNeed = requiredExtent(first, along: axis, minCell: minCell)
            let secondNeed = requiredExtent(second, along: axis, minCell: minCell)
            return splitAxis == axis ? firstNeed + secondNeed : max(firstNeed, secondNeed)
        }
    }

    /// Returns `node` with the subtree at `indices` replaced by `newNode`, or
    /// `nil` if the path is invalid.
    private static func replacing(_ node: GridNode, at indices: [Int], with newNode: GridNode) -> GridNode? {
        guard let head = indices.first else { return newNode }
        guard case let .split(axis, ratio, first, second) = node else { return nil }
        let tail = Array(indices.dropFirst())
        switch head {
        case 0:
            guard let updated = replacing(first, at: tail, with: newNode) else { return nil }
            return .split(axis: axis, ratio: ratio, first: updated, second: second)
        case 1:
            guard let updated = replacing(second, at: tail, with: newNode) else { return nil }
            return .split(axis: axis, ratio: ratio, first: first, second: updated)
        default:
            return nil
        }
    }
}
