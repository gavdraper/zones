import AppKit
import ZonesCore

/// Drives the hotkey-hint HUD off the keyboard monitor's modifier stream.
///
/// It debounces a short hold before showing — so quickly typed chords (e.g.
/// `⌃⌥`+→) never flash the hint — then keeps it in sync as the held modifiers
/// change, escalating the move hint to the region hint the moment `⌘` is added
/// and tearing down once the chord fires or the modifiers are released. Centres
/// the HUD on the screen of the window that a chord would act on.
@MainActor
final class HotkeyHintController: HotkeyHintObserver {
    private let window: HotkeyHintWindowController

    /// How long the chord modifiers must be held idle before the hint appears.
    private static let showDelay: TimeInterval = 0.4

    /// Whether the feature is on. Turning it off cancels any pending or showing
    /// hint immediately.
    var isEnabled: Bool {
        didSet {
            // Only react to an actual turn-off; turning on simply lets the next
            // modifier event arm the hint.
            if oldValue && !isEnabled { cancelAndHide() }
        }
    }

    private var showTimer: Timer?
    /// The content a scheduled (not-yet-shown) hint will display, used to avoid
    /// restarting the timer when an unrelated modifier change resolves the same
    /// hint.
    private var pendingContent: HotkeyHintContent?
    /// The content currently on screen, or `nil` when the HUD is hidden.
    private var shownContent: HotkeyHintContent?
    /// Set once a chord fires, suppressing the hint until the modifiers are fully
    /// released. Without this the hint would flicker back ~400ms after every
    /// snap while the chord is still held for the next nudge — the user has just
    /// demonstrated they know the keys, so we stay quiet until they re-arm.
    private var suppressedUntilRelease = false

    init(window: HotkeyHintWindowController, isEnabled: Bool) {
        self.window = window
        self.isEnabled = isEnabled
    }

    // MARK: - HotkeyHintObserver

    func keyboardMonitor(_ monitor: KeyboardMonitor, heldModifiersDidChange modifiers: Modifiers) {
        guard isEnabled else { return }

        guard let content = HotkeyHint.content(for: modifiers) else {
            // Held modifiers no longer arm a chord family — drop the hint and
            // clear any post-chord suppression so the next chord shows again.
            cancelAndHide()
            return
        }

        // A chord fired and the modifiers are still held: stay quiet until release.
        guard !suppressedUntilRelease else { return }

        if shownContent != nil {
            // Already visible: reflect a tier change (⌃⌥ → ⌃⌥⌘) at once.
            if shownContent != content { present(content) }
            return
        }

        // Not yet visible: (re)arm the debounce, unless it's already counting
        // down to this very content.
        guard pendingContent != content else { return }
        scheduleShow(content)
    }

    /// A bound chord fired; the action now owns the screen, so drop the hint and
    /// keep it down until the modifiers are released.
    func keyboardMonitorDidConsumeCommand(_ monitor: KeyboardMonitor) {
        cancelAndHide()
        suppressedUntilRelease = true
    }

    // MARK: - Presentation

    private func scheduleShow(_ content: HotkeyHintContent) {
        showTimer?.invalidate()
        pendingContent = content
        showTimer = Timer.scheduledTimer(withTimeInterval: Self.showDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.showTimer = nil
                self.pendingContent = nil
                guard self.isEnabled else { return }
                self.present(content)
            }
        }
    }

    private func present(_ content: HotkeyHintContent) {
        guard let screen = focusedWindowScreen() else { return }
        window.show(content, on: screen)
        shownContent = content
    }

    private func cancelAndHide() {
        showTimer?.invalidate()
        showTimer = nil
        pendingContent = nil
        suppressedUntilRelease = false
        if shownContent != nil {
            window.hide()
            shownContent = nil
        }
    }

    /// The screen holding the window a chord would act on — the focused window's,
    /// by its centre — falling back to the main screen when there's no focused
    /// window (e.g. the desktop is active).
    private func focusedWindowScreen() -> NSScreen? {
        guard let frame = FocusedWindow.current()?.frame() else { return NSScreen.main }
        let center = CGPoint(x: frame.midX, y: frame.midY)   // Quartz/AX coordinates
        return NSScreen.screens.first { screen in
            CoordinateSpace.quartz(fromAppKit: screen.frame).contains(center)
        } ?? NSScreen.main
    }
}
