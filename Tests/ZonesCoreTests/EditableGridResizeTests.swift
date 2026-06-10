import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Editable grid — resizing dividers")
struct EditableGridResizeTests {

    @Test("Dragging a divider changes sibling widths but conserves total area")
    func resizeConservesArea() {
        let grid = EditableGrid.single
            .splitting(.root, axis: .vertical, at: 0.5)
            .resizingDivider(.root, to: 0.7)
        let zones = grid.zones()

        #expect(zones[0].normalizedFrame.width.isApproximately(0.7))
        #expect(zones[1].normalizedFrame.width.isApproximately(0.3))
        #expect(totalArea(of: zones).isApproximately(1.0))
    }

    @Test("Resize clamps at the minimum cell fraction on both ends")
    func resizeClamps() {
        let split = EditableGrid.single.splitting(.root, axis: .vertical, at: 0.5)

        let collapsedLeft = split.resizingDivider(.root, to: 0.0).zones()
        #expect(collapsedLeft[0].normalizedFrame.width.isApproximately(0.05))

        let collapsedRight = split.resizingDivider(.root, to: 1.0).zones()
        #expect(collapsedRight[1].normalizedFrame.width.isApproximately(0.05))
    }

    @Test("Resizing respects the minimum extent of nested descendants")
    func resizeRespectsDescendantMinima() {
        // Right cell is itself split into two vertical cells, so it needs at least
        // 2 × minCellFraction (0.10) of total width.
        let grid = EditableGrid.single
            .splitting(.root, axis: .vertical, at: 0.5)
            .splitting(GridPath([1]), axis: .vertical, at: 0.5)

        let resized = grid.resizingDivider(.root, to: 0.95)
        let rightWidth = resized.rect(at: GridPath([1]))!.width
        #expect(rightWidth.isApproximately(0.10))
    }

    @Test("Resizing a leaf path is a no-op")
    func resizeLeafIsNoOp() {
        let grid = EditableGrid.single
        #expect(grid.resizingDivider(.root, to: 0.3) == grid)
    }
}
