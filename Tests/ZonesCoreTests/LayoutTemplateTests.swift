import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Layout templates")
struct LayoutTemplateTests {

    @Test("Columns produce N equal full-height zones")
    func columns() {
        let layout = LayoutTemplate.columns(3)
        #expect(layout.zones.count == 3)
        for (index, zone) in layout.zones.enumerated() {
            #expect(zone.normalizedFrame.width.isApproximately(1.0 / 3.0))
            #expect(zone.normalizedFrame.height == 1.0)
            #expect(zone.normalizedFrame.origin.x.isApproximately(Double(index) / 3.0))
            #expect(zone.normalizedFrame.origin.y == 0)
        }
    }

    @Test("Grid is row-major and tiles the unit square")
    func grid() {
        let layout = LayoutTemplate.grid(rows: 2, columns: 2)
        #expect(layout.zones.count == 4)
        #expect(layout.zones.map(\.id) == [0, 1, 2, 3])

        // id 3 is bottom-right.
        let bottomRight = layout.zones[3].normalizedFrame
        #expect(bottomRight.origin.x.isApproximately(0.5))
        #expect(bottomRight.origin.y.isApproximately(0.5))
        #expect(bottomRight.width.isApproximately(0.5))
        #expect(bottomRight.height.isApproximately(0.5))

        // Total covered area equals the whole display.
        let totalArea = layout.zones.reduce(0.0) { $0 + $1.normalizedFrame.width * $1.normalizedFrame.height }
        #expect(totalArea.isApproximately(1.0))
    }

    @Test("Priority grid is a 25/50/25 split")
    func priorityGrid() {
        let layout = LayoutTemplate.priorityGrid()
        #expect(layout.zones.map(\.normalizedFrame.width) == [0.25, 0.5, 0.25])
        let totalWidth = layout.zones.reduce(0.0) { $0 + $1.normalizedFrame.width }
        #expect(totalWidth.isApproximately(1.0))
    }
}

extension BinaryFloatingPoint {
    /// Tolerant equality for floating-point geometry comparisons.
    func isApproximately(_ other: Self, tolerance: Self = 1e-9) -> Bool {
        abs(self - other) <= tolerance
    }
}
