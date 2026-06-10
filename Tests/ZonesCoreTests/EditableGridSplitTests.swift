import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Editable grid — splitting")
struct EditableGridSplitTests {

    @Test("Splitting the single cell vertically yields two half-width, full-height cells")
    func verticalSplit() {
        let grid = EditableGrid.single.splitting(.root, axis: .vertical, at: 0.5)
        let zones = grid.zones()

        #expect(zones.count == 2)
        #expect(zones[0].normalizedFrame.isApproximately(CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        #expect(zones[1].normalizedFrame.isApproximately(CGRect(x: 0.5, y: 0, width: 0.5, height: 1)))
        #expect(totalArea(of: zones).isApproximately(1.0))
    }

    @Test("Splitting horizontally splits top/bottom (top-left origin)")
    func horizontalSplit() {
        let grid = EditableGrid.single.splitting(.root, axis: .horizontal, at: 0.5)
        let zones = grid.zones()

        #expect(zones.count == 2)
        // first child is the top half.
        #expect(zones[0].normalizedFrame.isApproximately(CGRect(x: 0, y: 0, width: 1, height: 0.5)))
        #expect(zones[1].normalizedFrame.isApproximately(CGRect(x: 0, y: 0.5, width: 1, height: 0.5)))
    }

    @Test("A nested split still tiles the unit square with no overlaps")
    func nestedSplitTiles() {
        let grid = EditableGrid.single
            .splitting(.root, axis: .vertical, at: 0.5)
            .splitting(GridPath([0]), axis: .horizontal, at: 0.5)
        let zones = grid.zones()

        #expect(zones.count == 3)
        #expect(totalArea(of: zones).isApproximately(1.0))
        #expect(maxPairwiseOverlap(of: zones).isApproximately(0.0))
    }

    @Test("Splitting a non-leaf path is a no-op")
    func splittingNonLeafIsNoOp() {
        let grid = EditableGrid.single.splitting(.root, axis: .vertical, at: 0.5)
        // root is now a split node — splitting it again should change nothing.
        #expect(grid.splitting(.root, axis: .horizontal, at: 0.5) == grid)
    }

    @Test("Split ratio is clamped to the minimum cell fraction")
    func splitRatioClamped() {
        let grid = EditableGrid.single.splitting(.root, axis: .vertical, at: 0.0)
        let zones = grid.zones()
        #expect(zones[0].normalizedFrame.width.isApproximately(0.05))
        #expect(zones[1].normalizedFrame.width.isApproximately(0.95))
    }
}
