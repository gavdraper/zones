import AppKit
import ZonesCore

/// Coordinates a drag gesture into a window snap: it finds the screen under the
/// cursor, hit-tests the active layout, drives the overlay, and on release
/// resizes the focused window into the chosen zone.
@MainActor
final class SnapController: DragMonitorDelegate {
    private let overlay: OverlayWindowController

    /// The layout currently offered for snapping. Swappable from the menu bar.
    var layout: ZoneLayout

    private var targetScreen: NSScreen?
    private var targetZone: Zone?
    private var draggedWindow: FocusedWindow?

    init(layout: ZoneLayout, overlay: OverlayWindowController) {
        self.layout = layout
        self.overlay = overlay
    }

    // MARK: - DragMonitorDelegate

    func dragDidBegin(at point: CGPoint, modifierActive: Bool) {
        // Capture the window now: at drop time the frontmost app may have
        // changed, but at drag start the focused window is the one being moved.
        draggedWindow = FocusedWindow.current()
        refresh(at: point, modifierActive: modifierActive)
    }

    func dragDidMove(to point: CGPoint, modifierActive: Bool) {
        refresh(at: point, modifierActive: modifierActive)
    }

    func dragDidEnd(at point: CGPoint, modifierActive: Bool) {
        defer { reset() }
        // A non-nil `targetZone` means the modifier was held on the last move and
        // a zone is armed. We deliberately don't re-check `modifierActive` here:
        // releasing Shift a few milliseconds before the mouse button emits the
        // keyUp first, so the flag is already clear at mouseUp and the snap would
        // be lost. Abandoning a snap mid-drag clears `targetZone` via refresh().
        guard let zone = targetZone,
              let screen = targetScreen,
              let window = draggedWindow else { return }

        let bounds = displayBoundsQuartz(for: screen)
        let frame = ZoneGeometry.frame(for: zone, in: bounds)
        Log.snap.info("Snapping to zone \(zone.id) frame=\(frame.debugDescription, privacy: .public)")
        window.setFrame(frame)
    }

    // MARK: - Snap state

    /// Recomputes the target screen/zone for the cursor and updates the overlay.
    /// When the modifier isn't held the overlay is hidden, so normal drags are
    /// untouched.
    private func refresh(at point: CGPoint, modifierActive: Bool) {
        guard modifierActive, let screen = screen(containing: point) else {
            reset()
            return
        }

        let bounds = displayBoundsQuartz(for: screen)
        targetScreen = screen
        targetZone = ZoneHitTester.zone(at: point, layout: layout, displayBounds: bounds)
        Log.snap.debug("refresh point=\(point.debugDescription, privacy: .public) zone=\(self.targetZone?.id ?? -1)")

        overlay.show(
            layout: layout,
            on: screen,
            displayBoundsQuartz: bounds,
            activeZoneID: targetZone?.id
        )
    }

    private func reset() {
        targetScreen = nil
        targetZone = nil
        draggedWindow = nil
        overlay.hide()
    }

    // MARK: - Screen geometry

    private func screen(containing pointQuartz: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            displayBoundsQuartz(for: screen).contains(pointQuartz)
        } ?? NSScreen.main
    }

    private func displayBoundsQuartz(for screen: NSScreen) -> CGRect {
        CoordinateSpace.quartz(fromAppKit: screen.visibleFrame)
    }
}
