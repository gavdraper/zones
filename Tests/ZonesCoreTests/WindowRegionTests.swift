import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Window regions")
struct WindowRegionTests {

    @Test("Halves map to the expected normalized frames")
    func halves() {
        #expect(WindowRegion.leftHalf.normalizedFrame == CGRect(x: 0, y: 0, width: 0.5, height: 1))
        #expect(WindowRegion.rightHalf.normalizedFrame == CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
        #expect(WindowRegion.topHalf.normalizedFrame == CGRect(x: 0, y: 0, width: 1, height: 0.5))
        #expect(WindowRegion.bottomHalf.normalizedFrame == CGRect(x: 0, y: 0.5, width: 1, height: 0.5))
    }

    @Test("Quarters map to the expected normalized frames")
    func quarters() {
        #expect(WindowRegion.topLeftQuarter.normalizedFrame == CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        #expect(WindowRegion.topRightQuarter.normalizedFrame == CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
        #expect(WindowRegion.bottomLeftQuarter.normalizedFrame == CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5))
        #expect(WindowRegion.bottomRightQuarter.normalizedFrame == CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    }

    @Test("Maximize fills the display")
    func maximize() {
        #expect(WindowRegion.maximize.normalizedFrame == CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    @Test("Center has no normalized frame — it preserves the window's size")
    func centerHasNoFrame() {
        #expect(WindowRegion.center.normalizedFrame == nil)
    }

    @Test("The four quarters tile the display without overlap or gaps")
    func quartersTile() {
        let quarters: [WindowRegion] = [
            .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter,
        ]
        let area = quarters.compactMap { $0.normalizedFrame }.reduce(0) { $0 + $1.width * $1.height }
        #expect(area == 1.0)
    }
}
