import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Coordinate flip")
struct CoordinateFlipTests {

    @Test("Primary-screen rect flips to its top-left equivalent")
    func primaryFlip() {
        // visibleFrame on a 1080-tall primary with a 25pt menu bar.
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1055)
        let quartz = CoordinateFlip.flip(visible, referenceHeight: 1080)
        // Top edge in Quartz sits at the menu-bar height.
        #expect(quartz == CGRect(x: 0, y: 25, width: 1920, height: 1055))
    }

    @Test("Flip is an involution for any reference height")
    func involution() {
        let rect = CGRect(x: 200, y: 300, width: 640, height: 480)
        let roundTrip = CoordinateFlip.flip(
            CoordinateFlip.flip(rect, referenceHeight: 1440),
            referenceHeight: 1440
        )
        #expect(roundTrip == rect)
    }

    @Test("Secondary display above the primary flips to a negative y")
    func secondaryAbovePrimary() {
        // A 1080-tall secondary stacked directly above a 1080-tall primary:
        // its AppKit origin.y is +1080, so in Quartz it sits above the origin.
        let secondary = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        let quartz = CoordinateFlip.flip(secondary, referenceHeight: 1080)
        #expect(quartz == CGRect(x: 0, y: -1080, width: 1920, height: 1080))
    }
}
