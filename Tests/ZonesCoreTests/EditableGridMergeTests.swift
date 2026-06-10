import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Editable grid — merging")
struct EditableGridMergeTests {

    @Test("Merging a split restores a single cell reclaiming the whole area")
    func mergeRestoresSingleCell() {
        let split = EditableGrid.single.splitting(.root, axis: .vertical, at: 0.3)
        let merged = split.merging(.root)

        let zones = merged.zones()
        #expect(zones.count == 1)
        #expect(zones[0].normalizedFrame.isApproximately(CGRect(x: 0, y: 0, width: 1, height: 1)))
    }

    @Test("Merge is the inverse of a 0.5 split")
    func mergeInvertsSplit() {
        let grid = EditableGrid.single
        let roundTrip = grid.splitting(.root, axis: .horizontal, at: 0.5).merging(.root)
        #expect(roundTrip == grid)
    }

    @Test("Merging an inner split leaves its siblings untouched")
    func mergeInnerSplit() {
        let grid = EditableGrid.single
            .splitting(.root, axis: .vertical, at: 0.5)   // left | right
            .splitting(GridPath([1]), axis: .horizontal, at: 0.5)   // split the right cell

        #expect(grid.zones().count == 3)

        let merged = grid.merging(GridPath([1]))   // collapse the right cell back
        let zones = merged.zones()
        #expect(zones.count == 2)
        #expect(zones[1].normalizedFrame.isApproximately(CGRect(x: 0.5, y: 0, width: 0.5, height: 1)))
    }

    @Test("Merging a leaf is a no-op")
    func mergingLeafIsNoOp() {
        let grid = EditableGrid.single
        #expect(grid.merging(.root) == grid)
    }

    @Test("mergingLeaf collapses a cell into a leaf sibling")
    func mergeLeafIntoLeafSibling() {
        let grid = EditableGrid.single.splitting(.root, axis: .vertical, at: 0.5)
        let merged = grid.mergingLeaf(at: GridPath([0]))   // merge left into right
        #expect(merged == EditableGrid.single)
    }

    @Test("mergingLeaf is a no-op when the sibling is subdivided (no data loss)")
    func mergeLeafPreservesSubdividedSibling() {
        // left | right, with the right cell split into two.
        let grid = EditableGrid.single
            .splitting(.root, axis: .vertical, at: 0.5)
            .splitting(GridPath([1]), axis: .horizontal, at: 0.5)

        // Merging the left cell must NOT collapse the subdivided right sibling.
        let merged = grid.mergingLeaf(at: GridPath([0]))
        #expect(merged == grid)
        #expect(merged.zones().count == 3)
    }

    @Test("mergingLeaf on the root cell is a no-op")
    func mergeLeafRootIsNoOp() {
        let grid = EditableGrid.single
        #expect(grid.mergingLeaf(at: .root) == grid)
    }
}
