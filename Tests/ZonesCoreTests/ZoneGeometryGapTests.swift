import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Zone geometry — gaps")
struct ZoneGeometryGapTests {

    private let display = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    @Test("Zero gap is identical to the gapless mapping")
    func zeroGapIsNoOp() {
        let normalized = CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        #expect(
            ZoneGeometry.frame(forNormalized: normalized, in: display, gap: 0)
                == CGRect(x: 960, y: 0, width: 960, height: 1080)
        )
    }

    @Test("Default gap argument preserves existing zone mapping")
    func defaultGapMatchesLegacy() {
        let zone = Zone(id: 0, normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        #expect(ZoneGeometry.frame(for: zone, in: display)
            == ZoneGeometry.frame(for: zone, in: display, gap: 0))
    }

    @Test("Gap is uniform between adjacent windows and at the screen edges")
    func uniformGap() {
        let gap: CGFloat = 20
        let left = ZoneGeometry.frame(
            forNormalized: CGRect(x: 0, y: 0, width: 0.5, height: 1), in: display, gap: gap
        )
        let right = ZoneGeometry.frame(
            forNormalized: CGRect(x: 0.5, y: 0, width: 0.5, height: 1), in: display, gap: gap
        )

        // Outer margins equal the gap on every screen edge.
        #expect(left.minX == gap)                    // left edge
        #expect(left.minY == gap)                    // top edge
        #expect(display.maxY - left.maxY == gap)     // bottom edge
        #expect(display.maxX - right.maxX == gap)    // right edge
        // The space between the two windows also equals the gap.
        #expect(right.minX - left.maxX == gap)
    }

    @Test("Gap is uniform for a zone bordered on both sides (thirds)")
    func uniformGapAcrossThirds() {
        let gap: CGFloat = 30
        let third = CGFloat(1) / 3
        let a = ZoneGeometry.frame(forNormalized: CGRect(x: 0, y: 0, width: third, height: 1), in: display, gap: gap)
        let b = ZoneGeometry.frame(forNormalized: CGRect(x: third, y: 0, width: third, height: 1), in: display, gap: gap)
        let c = ZoneGeometry.frame(forNormalized: CGRect(x: 2 * third, y: 0, width: third, height: 1), in: display, gap: gap)

        #expect(abs((b.minX - a.maxX) - gap) < 0.001)   // interior gap A|B
        #expect(abs((c.minX - b.maxX) - gap) < 0.001)   // interior gap B|C
        #expect(abs(a.minX - gap) < 0.001)              // left edge
        #expect(abs((display.maxX - c.maxX) - gap) < 0.001)  // right edge
    }

    @Test("Centered clamps to a non-negative size when the gap exceeds the display")
    func centeredClampsNonNegative() {
        let frame = ZoneGeometry.centered(size: CGSize(width: 800, height: 600), in: display, gap: 5000)
        #expect(frame.width >= 0)
        #expect(frame.height >= 0)
    }

    @Test("Gap larger than the zone clamps to a non-negative size")
    func oversizedGapClamps() {
        let frame = ZoneGeometry.frame(
            forNormalized: CGRect(x: 0, y: 0, width: 0.1, height: 0.1), in: display, gap: 1000
        )
        #expect(frame.width >= 0)
        #expect(frame.height >= 0)
    }

    @Test("Centered keeps the given size and centers it in the display")
    func centeredKeepsSize() {
        let frame = ZoneGeometry.centered(size: CGSize(width: 800, height: 600), in: display, gap: 0)
        #expect(frame == CGRect(x: 560, y: 240, width: 800, height: 600))
    }

    @Test("Centered shrinks a size larger than the gap-inset work area")
    func centeredClampsToWorkArea() {
        let frame = ZoneGeometry.centered(
            size: CGSize(width: 5000, height: 5000), in: display, gap: 40
        )
        #expect(frame == CGRect(x: 20, y: 20, width: 1880, height: 1040))
    }
}
