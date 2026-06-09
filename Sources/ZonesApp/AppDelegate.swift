import AppKit
import ZonesCore

/// Composition root: wires the accessibility check, drag monitor, snap
/// controller, overlay, and menu bar together once the app finishes launching.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: OverlayWindowController?
    private var dragMonitor: DragMonitor?
    private var snapController: SnapController?
    private var menuBar: MenuBarController?
    private var trustPoll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let overlay = OverlayWindowController()
        let snapController = SnapController(layout: LayoutTemplate.columns(3), overlay: overlay)
        let dragMonitor = DragMonitor()
        dragMonitor.delegate = snapController

        let menuBar = MenuBarController(dragMonitor: dragMonitor, snapController: snapController)

        self.overlay = overlay
        self.snapController = snapController
        self.dragMonitor = dragMonitor
        self.menuBar = menuBar

        startMonitoringWhenTrusted()
    }

    /// Starts the drag monitor immediately if Accessibility is already granted;
    /// otherwise prompts and polls until the user grants it (the permission is
    /// often granted *after* launch, and the event tap can't install until then).
    private func startMonitoringWhenTrusted() {
        if AccessibilityAuthorizer.isTrusted {
            Log.app.info("Accessibility trusted at launch — starting monitor")
            dragMonitor?.start()
            return
        }

        Log.app.info("Accessibility not trusted — prompting and polling")
        AccessibilityAuthorizer.promptIfNeeded()

        trustPoll = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Timers on the main run loop fire on the main thread.
            MainActor.assumeIsolated {
                guard let self, AccessibilityAuthorizer.isTrusted else { return }
                Log.app.info("Accessibility granted — starting monitor")
                self.dragMonitor?.start()
                self.menuBar?.refresh()
                self.trustPoll?.invalidate()
                self.trustPoll = nil
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        trustPoll?.invalidate()
        dragMonitor?.stop()
    }
}
