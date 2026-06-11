import AppKit
import ZonesCore

/// Coordinates a drag gesture into a window snap: it finds the screen under the
/// cursor, hit-tests the active layout, drives the overlay, and on release
/// resizes the focused window into the chosen zone.
@MainActor
final class SnapController: DragMonitorDelegate, KeyboardMonitorDelegate {
    private let overlay: OverlayWindowController

    /// The layout currently offered for snapping. Swappable from the menu bar.
    var layout: ZoneLayout

    /// Spacing in points inset around every snapped window. Driven by the
    /// library so menu changes take effect on the next snap.
    var gap: CGFloat = 0

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
        let frame = ZoneGeometry.frame(for: zone, in: bounds, gap: gap)
        Log.snap.info("Snapping to zone \(zone.id) frame=\(frame.debugDescription, privacy: .public)")
        window.setFrame(frame)
    }

    // MARK: - KeyboardMonitorDelegate

    func keyboardMonitor(_ monitor: KeyboardMonitor, didRequestMoveIn direction: ZoneNavigator.Direction) {
        moveFocusedWindow(direction)
    }

    /// Snaps the focused window to a built-in screen region on its current
    /// display. No layout is involved, so no overlay is shown.
    func keyboardMonitor(_ monitor: KeyboardMonitor, didRequestRegion region: WindowRegion) {
        guard let context = focusedWindowContext() else { return }

        let frame: CGRect
        if let normalized = region.normalizedFrame {
            frame = ZoneGeometry.frame(forNormalized: normalized, in: context.bounds, gap: gap)
        } else {
            // `.center` keeps the window's current size and only recenters it.
            frame = ZoneGeometry.centered(size: context.windowFrame.size, in: context.bounds, gap: gap)
        }
        Log.snap.info("Region snap \(String(describing: region), privacy: .public) frame=\(frame.debugDescription, privacy: .public)")
        context.window.setFrame(frame)
    }

    /// Releasing the hotkey modifiers ends the gesture, so the zone overlay that
    /// has been shown since the first move is torn down.
    func keyboardMonitorDidDisengage(_ monitor: KeyboardMonitor) {
        overlay.hide()
    }

    /// Steps the focused window to the zone neighbouring its current one in
    /// `direction` and highlights the target. The overlay stays up until the
    /// modifiers are released (see ``keyboardMonitorDidDisengage(_:)``) so repeated
    /// presses can walk the window across zones. A window that occupies no zone is
    /// pulled into the nearest one; a window already at the layout edge stays put.
    private func moveFocusedWindow(_ direction: ZoneNavigator.Direction) {
        guard let context = focusedWindowContext() else { return }
        let bounds = context.bounds

        guard let zone = destinationZone(for: context.windowFrame, direction: direction, in: bounds) else { return }

        let frame = ZoneGeometry.frame(for: zone, in: bounds, gap: gap)
        Log.snap.info("Keyboard move \(String(describing: direction), privacy: .public) → zone \(zone.id)")
        context.window.setFrame(frame)
        overlay.show(layout: layout, on: context.screen, displayBoundsQuartz: bounds, activeZoneID: zone.id)
    }

    /// The focused window, its current frame, and the screen/bounds it sits on
    /// (by its centre) — the common preamble for keyboard-driven placement.
    private func focusedWindowContext()
        -> (window: FocusedWindow, windowFrame: CGRect, screen: NSScreen, bounds: CGRect)? {
        guard let window = FocusedWindow.current(), let windowFrame = window.frame() else { return nil }
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        guard let screen = screen(containing: center) else { return nil }
        return (window, windowFrame, screen, displayBoundsQuartz(for: screen))
    }

    private func destinationZone(
        for windowFrame: CGRect,
        direction: ZoneNavigator.Direction,
        in bounds: CGRect
    ) -> Zone? {
        guard let current = ZoneNavigator.currentZone(forWindowFrame: windowFrame, layout: layout, displayBounds: bounds) else {
            // Not in a zone yet — land it in the nearest one.
            return ZoneNavigator.nearestZone(to: CGPoint(x: windowFrame.midX, y: windowFrame.midY), layout: layout, displayBounds: bounds)
        }
        return ZoneNavigator.adjacentZone(from: current, direction: direction, in: layout)
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
