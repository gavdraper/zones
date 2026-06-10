/// A value-typed address of a node within a `GridNode` tree.
///
/// Each element is a child choice from the root: `0` descends into a split's
/// `first` child, `1` into its `second`. An empty path addresses the root.
/// Using a path (rather than baking ids into the tree) keeps `GridNode` purely
/// structural while still letting the editor refer to "the clicked leaf" or
/// "the dragged divider".
public struct GridPath: Equatable, Hashable, Codable, Sendable {
    public let indices: [Int]

    public init(_ indices: [Int] = []) {
        self.indices = indices
    }

    /// The root node's path.
    public static let root = GridPath()

    /// The path of the `index`-th child of the node at this path.
    public func appending(_ index: Int) -> GridPath {
        GridPath(indices + [index])
    }
}
