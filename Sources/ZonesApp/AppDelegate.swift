import AppKit
import ZonesCore

/// Composition root: loads the layout library, wires the accessibility check,
/// drag monitor, snap controller, overlay, and menu bar together, and owns the
/// editor window while it's open.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: OverlayWindowController?
    private var dragMonitor: DragMonitor?
    private var keyboardMonitor: KeyboardMonitor?
    private var snapController: SnapController?
    private var hintController: HotkeyHintController?
    private var menuBar: MenuBarController?
    private var library: LayoutLibrary?
    private var editor: EditorWindowController?
    private var settings: SettingsWindowController?
    private var help: HelpWindowController?
    private var updateController: UpdateController?
    private var trustPoll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let library = loadLibrary()
        let overlay = OverlayWindowController()
        let snapController = SnapController(layout: library.active, overlay: overlay)
        snapController.gap = library.gap
        let dragMonitor = DragMonitor()
        dragMonitor.delegate = snapController
        let keyboardMonitor = KeyboardMonitor()
        keyboardMonitor.delegate = snapController
        keyboardMonitor.scheme = library.hotkeyScheme

        // The hint HUD observes the same keyboard monitor, independently of
        // snapping, to show the available hotkeys while the modifiers are held.
        let hintController = HotkeyHintController(
            window: HotkeyHintWindowController(),
            isEnabled: library.hintsEnabled
        )
        hintController.scheme = library.hotkeyScheme
        keyboardMonitor.hintObserver = hintController

        // Sparkle drives auto-updates; it reads its config from the bundle's
        // Info.plist, so it only does anything in a real packaged build.
        let updateController = UpdateController()

        let menuBar = MenuBarController(
            library: library,
            onNewLayout: { [weak self] in self?.openEditor(editing: nil) },
            onEditLayout: { [weak self] layout in self?.openEditor(editing: layout) },
            onShowSettings: { [weak self] in self?.openSettings() },
            onShowHelp: { [weak self] in self?.openHelp() },
            makeUpdateMenuItem: { [weak updateController] in updateController?.makeMenuItem() }
        )

        // When settings or the active layout change (menu pick, editor save, or
        // the Settings window), push the new state into the snap controller,
        // input monitor, and hint HUD, and refresh the menu's checkmarks.
        library.onChange = { [weak snapController, weak keyboardMonitor, weak hintController, weak menuBar] in
            snapController?.layout = library.active
            snapController?.gap = library.gap
            keyboardMonitor?.scheme = library.hotkeyScheme
            hintController?.isEnabled = library.hintsEnabled
            hintController?.scheme = library.hotkeyScheme
            menuBar?.refresh()
        }

        self.library = library
        self.updateController = updateController
        self.overlay = overlay
        self.snapController = snapController
        self.dragMonitor = dragMonitor
        self.keyboardMonitor = keyboardMonitor
        self.hintController = hintController
        self.menuBar = menuBar

        startMonitoringWhenTrusted()
    }

    /// Loads the persisted library, falling back to a non-persistent one if the
    /// store can't be reached so the app still runs with the built-in layouts.
    private func loadLibrary() -> LayoutLibrary {
        let builtins = LayoutTemplate.builtins()
        do {
            return try LayoutLibrary(store: try FileLayoutStore.standard(), builtins: builtins)
        } catch {
            Log.app.error("Layout store unavailable (\(error.localizedDescription, privacy: .public)); using defaults")
            // EphemeralLayoutStore never fails, so this force-try is safe.
            return try! LayoutLibrary(store: EphemeralLayoutStore(), builtins: builtins)
        }
    }

    private func openEditor(editing layout: UserLayout?) {
        // Re-use the existing window rather than stacking editors.
        if let editor {
            editor.show()
            return
        }
        let controller = EditorWindowController(
            editing: layout,
            onSave: { [weak self] saved in
                guard let self, let library = self.library else { return }
                if layout == nil {
                    library.add(saved)
                } else {
                    library.update(saved)
                }
            },
            onClose: { [weak self] in
                self?.editor = nil
                self?.demoteIfNoWindowsOpen()
            }
        )
        self.editor = controller
        controller.show()
    }

    private func openSettings() {
        // Re-use the existing window rather than stacking settings panes.
        if let settings {
            settings.show()
            return
        }
        guard let library else { return }
        let controller = SettingsWindowController(
            library: library,
            onClose: { [weak self] in
                self?.settings = nil
                self?.demoteIfNoWindowsOpen()
            }
        )
        self.settings = controller
        controller.show()
    }

    private func openHelp() {
        // Re-use the existing window rather than stacking help screens.
        if let help {
            help.show()
            return
        }
        guard let library else { return }
        let controller = HelpWindowController(
            hotkeyScheme: library.hotkeyScheme,
            onClose: { [weak self] in
                self?.help = nil
                self?.demoteIfNoWindowsOpen()
            }
        )
        self.help = controller
        controller.show()
    }

    /// Returns the app to a menu-bar agent (`.accessory`) once the last managed
    /// window has closed. Each controller promotes to `.regular` when it opens;
    /// demotion is centralized here so closing one window never hides another
    /// that's still on screen.
    private func demoteIfNoWindowsOpen() {
        guard editor == nil, settings == nil, help == nil else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    /// Starts the drag monitor immediately if Accessibility is already granted;
    /// otherwise prompts and polls until the user grants it (the permission is
    /// often granted *after* launch, and the event tap can't install until then).
    private func startMonitoringWhenTrusted() {
        if AccessibilityAuthorizer.isTrusted {
            Log.app.info("Accessibility trusted at launch — starting monitors")
            startMonitors()
            return
        }

        Log.app.info("Accessibility not trusted — prompting and polling")
        AccessibilityAuthorizer.promptIfNeeded()

        trustPoll = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AccessibilityAuthorizer.isTrusted else { return }
                Log.app.info("Accessibility granted — starting monitors")
                self.startMonitors()
                self.menuBar?.refresh()
                self.trustPoll?.invalidate()
                self.trustPoll = nil
            }
        }
    }

    /// Starts mouse-drag and keyboard snapping together.
    private func startMonitors() {
        dragMonitor?.start()
        keyboardMonitor?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        trustPoll?.invalidate()
        dragMonitor?.stop()
        keyboardMonitor?.stop()
    }
}
