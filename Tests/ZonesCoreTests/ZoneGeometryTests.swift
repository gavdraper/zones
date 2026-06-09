import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Zone geometry & hit-testing")
struct ZoneGeometryTests {

    private let display = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test("Normalized frame maps to pixel frame within the display")
    func frameMapping() {
        let zone = Zone(id: 0, normalizedFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
        let frame = ZoneGeometry.frame(for: zone, in: display)
        #expect(frame == CGRect(x: 960, y: 0, width: 960, height: 1080))
    }

    @Test("Frame respects a non-zero display origin")
    func frameRespectsOrigin() {
        let offsetDisplay = CGRect(x: 1920, y: 100, width: 1920, height: 1080)
        let zone = Zone(id: 0, normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        let frame = ZoneGeometry.frame(for: zone, in: offsetDisplay)
        #expect(frame == CGRect(x: 1920, y: 100, width: 960, height: 540))
    }

    @Test("Hit test returns the zone containing the point")
    func hitTestMatch() {
        let layout = LayoutTemplate.columns(3)
        // Point in the middle column.
        let hit = ZoneHitTester.zone(at: CGPoint(x: 960, y: 540), layout: layout, displayBounds: display)
        #expect(hit?.id == 1)
    }

    @Test("Hit test returns nil outside all zones")
    func hitTestMiss() {
        let layout = LayoutTemplate.columns(3)
        let hit = ZoneHitTester.zone(at: CGPoint(x: -10, y: 540), layout: layout, displayBounds: display)
        #expect(hit == nil)
    }

    @Test("Overlapping zones resolve to the smallest")
    func hitTestPrefersSmallest() {
        let big = Zone(id: 0, normalizedFrame: CGRect(x: 0, y: 0, width: 1, height: 1))
        let small = Zone(id: 1, normalizedFrame: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2))
        let layout = ZoneLayout(name: "overlap", zones: [big, small])
        let hit = ZoneHitTester.zone(at: CGPoint(x: 960, y: 540), layout: layout, displayBounds: display)
        #expect(hit?.id == 1)
    }
}
