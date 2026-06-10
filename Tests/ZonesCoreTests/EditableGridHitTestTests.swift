import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Editable grid — hit testing")
struct EditableGridHitTestTests {

    private var grid: EditableGrid {
        EditableGrid.single
            .splitting(.root, axis: .vertical, at: 0.5)            // left | right
            .splitting(GridPath([0]), axis: .horizontal, at: 0.5)  // left → top/bottom
    }

    @Test("leafPath(at:) returns the containing leaf for interior points")
    func interiorPoints() {
        #expect(grid.leafPath(at: CGPoint(x: 0.25, y: 0.25)) == GridPath([0, 0]))  // left-top
        #expect(grid.leafPath(at: CGPoint(x: 0.25, y: 0.75)) == GridPath([0, 1]))  // left-bottom
        #expect(grid.leafPath(at: CGPoint(x: 0.75, y: 0.50)) == GridPath([1]))     // right
    }

    @Test("leafPath(at:) returns nil outside the unit square")
    func outsidePoints() {
        #expect(grid.leafPath(at: CGPoint(x: -0.1, y: 0.5)) == nil)
        #expect(grid.leafPath(at: CGPoint(x: 1.5, y: 0.5)) == nil)
    }

    @Test("dividers() exposes each split with its owning path and line geometry")
    func dividerGeometry() {
        let dividers = grid.dividers()
        #expect(dividers.count == 2)

        let root = dividers.first { $0.id == .root }
        #expect(root?.axis == .vertical)
        #expect(root?.bounds.isApproximately(CGRect(x: 0.5, y: 0, width: 0, height: 1)) == true)

        let inner = dividers.first { $0.id == GridPath([0]) }
        #expect(inner?.axis == .horizontal)
        // The inner divider spans only the left half's width at its mid-height.
        #expect(inner?.bounds.isApproximately(CGRect(x: 0, y: 0.5, width: 0.5, height: 0)) == true)
    }
}
