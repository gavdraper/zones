import AppKit

/// Draws zone outlines and highlights the active one. Purely presentational:
/// it receives view-local rects already converted by the controller and knows
/// nothing about coordinate spaces or layouts.
final class ZoneOverlayView: NSView {

    /// Zone rectangles in this view's (bottom-left) coordinate space.
    var zoneRects: [(id: Int, rect: CGRect)] = [] {
        didSet { needsDisplay = true }
    }

    /// The zone currently under the cursor, drawn filled.
    var activeZoneID: Int? {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: CGRect) {
        for zone in zoneRects {
            let path = NSBezierPath(roundedRect: zone.rect.insetBy(dx: 6, dy: 6), xRadius: 10, yRadius: 10)

            if zone.id == activeZoneID {
                NSColor.controlAccentColor.withAlphaComponent(0.35).setFill()
                path.fill()
                NSColor.controlAccentColor.setStroke()
                path.lineWidth = 3
            } else {
                NSColor.white.withAlphaComponent(0.10).setFill()
                path.fill()
                NSColor.white.withAlphaComponent(0.55).setStroke()
                path.lineWidth = 1.5
            }
            path.stroke()
        }
    }
}
