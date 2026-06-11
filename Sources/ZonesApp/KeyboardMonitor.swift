import AppKit
import ZonesCore

/// Receives keyboard gestures: a directional zone move (while the move
/// modifiers are held), a built-in size-region snap, and the moment the move
/// modifiers are released so any zone overlay shown during the gesture can be
/// torn down.
@MainActor
protocol KeyboardMonitorDelegate: AnyObject {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didRequestMoveIn direction: ZoneNavigator.Direction)
    func keyboardMonitor(_ monitor: KeyboardMonitor, didRequestRegion region: WindowRegion)
    func keyboardMonitorDidDisengage(_ monitor: KeyboardMonitor)
}

/// Observes the modifier state independently of any chord, so a transient
/// on-screen hint can track which keys are held and dismiss itself once a chord
/// fires. Kept separate from ``KeyboardMonitorDelegate`` (which owns snapping)
/// so the hint is a self-contained, optional concern.
@MainActor
protocol HotkeyHintObserver: AnyObject {
    /// The set of held modifier keys changed (fired on every `flagsChanged`).
    func keyboardMonitor(_ monitor: KeyboardMonitor, heldModifiersDidChange modifiers: Modifiers)
    /// A bound chord was just consumed; any showing hint should be torn down.
    func keyboardMonitorDidConsumeCommand(_ monitor: KeyboardMonitor)
}

/// Listens via a session-level `CGEventTap` for the two keyboard chord families
/// resolved by ``KeyBinding`` — zone moves (`⌃⌥`+arrows) and built-in size
/// regions (`⌃⌥⌘`+key) — and reports them to its delegate. Unlike
/// ``DragMonitor`` this tap is active (not listen-only) so it can swallow a
/// matched chord and stop the key from also reaching the focused app.
@MainActor
final class KeyboardMonitor: InputMonitor {
    weak var delegate: KeyboardMonitorDelegate?
    weak var hintObserver: HotkeyHintObserver?

    /// The active modifier preset that arms the chord families. Updated by the
    /// composition root when the user changes it in Settings.
    var scheme: HotkeyScheme = .default

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// True once a move has shown the overlay, until the move modifiers are
    /// released. Gates the disengage callback so it only fires for gestures we
    /// started (a region snap never engages the overlay).
    private var engaged = false

    var isRunning: Bool { eventTap != nil }

    /// Installs the event tap on the main run loop. Requires Accessibility
    /// permission; returns `false` if the tap could not be created.
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)   // to notice the modifiers being released
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,                 // active: lets us swallow the chord
            eventsOfInterest: mask,
            callback: keyboardTapCallback,
            userInfo: refcon
        ) else {
            Log.app.error("Keyboard CGEvent.tapCreate returned nil — Accessibility not granted?")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        Log.app.info("Keyboard monitor installed and enabled")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        engaged = false
    }

    /// Handles a key event. Returns `true` when a chord matched and the event
    /// should be swallowed.
    fileprivate func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) -> Bool {
        // An active tap that the system disables stops swallowing the hotkey, so
        // a silent failure here is user-visible — log it as we re-arm.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Log.app.error("Keyboard tap disabled (\(type.rawValue, privacy: .public)) — re-enabling")
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }

        let modifiers = Self.modifiers(from: flags)

        // Modifier changes are never consumed; we only watch them to learn when
        // the held move chord is let go, so the overlay can be dismissed.
        if type == .flagsChanged {
            if engaged && !modifiers.contains(scheme.moveModifiers) {
                engaged = false
                delegate?.keyboardMonitorDidDisengage(self)
            }
            hintObserver?.keyboardMonitor(self, heldModifiersDidChange: modifiers)
            return false
        }

        guard type == .keyDown,
              let command = KeyBinding.command(forKeyCode: keyCode, modifiers: modifiers, scheme: scheme) else { return false }

        switch command {
        case let .move(direction):
            engaged = true
            Log.app.debug("Zone-move hotkey: \(String(describing: direction), privacy: .public)")
            delegate?.keyboardMonitor(self, didRequestMoveIn: direction)
        case let .region(region):
            Log.app.debug("Size-region hotkey: \(String(describing: region), privacy: .public)")
            delegate?.keyboardMonitor(self, didRequestRegion: region)
        }
        // The action takes over the screen (zone overlay, or the snap itself), so
        // dismiss any hint that was showing the available keys.
        hintObserver?.keyboardMonitorDidConsumeCommand(self)
        return true
    }

    /// Maps the macOS event flags to the framework-agnostic ``Modifiers`` set,
    /// keeping only the four bits the bindings care about so stray
    /// device-dependent flags (caps lock, numeric pad) can't break the exact
    /// match `KeyBinding` performs.
    private static func modifiers(from flags: CGEventFlags) -> Modifiers {
        var modifiers: Modifiers = []
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        return modifiers
    }
}

/// C-compatible tap callback. The tap lives on the main run loop, so this fires
/// on the main thread; it forwards to the owning monitor and swallows the event
/// when the chord matched.
private func keyboardTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    dispatchPrecondition(condition: .onQueue(.main))
    guard let userInfo else { return Unmanaged.passUnretained(event) }

    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    let consumed = MainActor.assumeIsolated {
        monitor.handle(type: type, keyCode: keyCode, flags: flags)
    }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
