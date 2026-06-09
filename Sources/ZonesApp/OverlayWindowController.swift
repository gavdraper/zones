import AppKit
import ZonesCore

/// Owns the transparent, click-through window that visualises zones during a
/// drag, and translates zone geometry into the window's local coordinates.
@MainActor
final class OverlayWindowController {
    private let window: NSWindow
    private let overlayView = ZoneOverlayView()

    init() {
        window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true          // never intercept the drag
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.contentView = overlayView
    }

    /// Shows the overlay for `layout` on `screen`, highlighting `activeZoneID`.
    /// `displayBoundsQuartz` is the snapping region (the screen's visible frame)
    /// in Quartz/AX coordinates — the same region zones are measured against.
    func show(
        layout: ZoneLayout,
        on screen: NSScreen,
        displayBoundsQuartz: CGRect,
        activeZoneID: Int?
    ) {
        window.setFrame(screen.visibleFrame, display: true)
        overlayView.zoneRects = layout.zones.map { zone in
            (id: zone.id, rect: viewLocalRect(for: zone, displayBoundsQuartz: displayBoundsQuartz, windowOrigin: screen.visibleFrame.origin))
        }
        overlayView.activeZoneID = activeZoneID
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    // MARK: - Geometry

    private func viewLocalRect(
        for zone: Zone,
        displayBoundsQuartz: CGRect,
        windowOrigin: CGPoint
    ) -> CGRect {
        let quartzFrame = ZoneGeometry.frame(for: zone, in: displayBoundsQuartz)
        let appKitFrame = CoordinateSpace.appKit(fromQuartz: quartzFrame)
        return appKitFrame.offsetBy(dx: -windowOrigin.x, dy: -windowOrigin.y)
    }
}
