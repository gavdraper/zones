import Foundation
import CoreGraphics
import ZonesCore

/// The editor's interaction brain: it owns the working `EditableGrid`, applies
/// the pure grid mutations, drives undo/redo, and commits the result as a
/// `UserLayout`. It is deliberately AppKit-free — it works in unit-square
/// coordinates (`0...1`) and lets the view do pixel↔unit mapping — so the hard
/// logic stays separable from rendering.
@MainActor
final class GridEditorViewModel {
    private(set) var grid: EditableGrid
    var name: String

    /// Called whenever `grid` changes so the view can redraw.
    var onChange: (() -> Void)?

    private let existingID: UUID?
    private let undoManager: UndoManager
    private let onCommit: (UserLayout) -> Void

    /// Snapshot taken at the start of an interactive divider drag, so the whole
    /// drag collapses into a single undo step.
    private var dragStartGrid: EditableGrid?

    /// - Parameter layout: an existing layout to edit, or `nil` to start a new
    ///   single-cell layout.
    init(
        layout: UserLayout? = nil,
        undoManager: UndoManager,
        onCommit: @escaping (UserLayout) -> Void
    ) {
        self.existingID = layout?.id
        self.name = layout?.name ?? "Custom Layout"
        self.grid = layout?.grid ?? .single
        self.undoManager = undoManager
        self.onCommit = onCommit
    }

    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }

    // MARK: - Discrete edits

    /// Splits the cell containing `point` (unit coordinates) along `axis`.
    func splitCell(at point: CGPoint, axis: GridAxis) {
        guard let path = grid.leafPath(at: point) else { return }
        Log.editor.debug("split request axis=\(String(describing: axis), privacy: .public) path=\(path.indices, privacy: .public)")
        apply(grid.splitting(path, axis: axis), actionName: "Split Zone")
    }

    /// Merges the cell containing `point` into its sibling. Only collapses when
    /// the sibling is also a single cell, so a subdivided neighbour is never
    /// destroyed; the root cell (no sibling) is a no-op.
    func mergeCell(at point: CGPoint) {
        guard let path = grid.leafPath(at: point) else { return }
        Log.editor.debug("merge request leaf=\(path.indices, privacy: .public)")
        apply(grid.mergingLeaf(at: path), actionName: "Merge Zone")
    }

    // MARK: - Interactive divider drag (one undo step per drag)

    func beginResize() {
        dragStartGrid = grid
    }

    /// Live preview during a drag — updates the grid without registering undo.
    func updateResize(_ divider: GridPath, to ratio: Double) {
        grid = grid.resizingDivider(divider, to: ratio)
        onChange?()
    }

    func endResize() {
        guard let start = dragStartGrid else { return }
        dragStartGrid = nil
        let final = grid
        guard final != start else { return }
        grid = start                       // rewind so `apply` records the full delta
        apply(final, actionName: "Resize Zone")
    }

    // MARK: - Commit

    /// Builds the `UserLayout` (preserving identity when editing an existing one)
    /// and hands it to the commit callback.
    func commit() {
        let layout = UserLayout(id: existingID ?? UUID(), name: name, grid: grid)
        Log.editor.info("commit layout \"\(self.name, privacy: .public)\" zones=\(self.grid.zones().count)")
        onCommit(layout)
    }

    // MARK: - Undo plumbing

    private func apply(_ newGrid: EditableGrid, actionName: String) {
        guard newGrid != grid else { return }
        let previous = grid
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                target.apply(previous, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
        grid = newGrid
        onChange?()
    }
}
