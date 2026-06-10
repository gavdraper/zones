import Testing
import Foundation
import CoreGraphics
@testable import ZonesCore

@Suite("Editable grid — flattening & coding")
struct EditableGridFlattenTests {

    @Test("Flatten assigns deterministic depth-first ids")
    func deterministicIDs() {
        let grid = EditableGrid.single
            .splitting(.root, axis: .vertical, at: 0.5)            // left | right
            .splitting(GridPath([0]), axis: .horizontal, at: 0.5)  // split left into top/bottom
        let zones = grid.zones()

        // left-top = 0, left-bottom = 1, right = 2
        #expect(zones.map(\.id) == [0, 1, 2])
        #expect(zones[0].normalizedFrame.isApproximately(CGRect(x: 0, y: 0, width: 0.5, height: 0.5)))
        #expect(zones[1].normalizedFrame.isApproximately(CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)))
        #expect(zones[2].normalizedFrame.isApproximately(CGRect(x: 0.5, y: 0, width: 0.5, height: 1)))
    }

    @Test("layout(named:) wraps the flattened zones")
    func layoutNaming() {
        let layout = EditableGrid.single.splitting(.root, axis: .vertical, at: 0.5).layout(named: "Halves")
        #expect(layout.name == "Halves")
        #expect(layout.zones.count == 2)
    }

    @Test("EditableGrid round-trips through Codable unchanged")
    func codableRoundTrip() throws {
        let grid = EditableGrid.single
            .splitting(.root, axis: .vertical, at: 0.4)
            .splitting(GridPath([1]), axis: .horizontal, at: 0.6)

        let data = try JSONEncoder().encode(grid)
        let decoded = try JSONDecoder().decode(EditableGrid.self, from: data)
        #expect(decoded == grid)
    }
}
