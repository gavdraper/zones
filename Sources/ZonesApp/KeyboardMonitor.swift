import AppKit
import ZonesCore

/// Receives keyboard zone-move gestures: a directional move while the hotkey
/// modifiers are held, and the moment those modifiers are released so any zone
/// overlay shown during the gesture can be torn down.
@MainActor
protocol KeyboardMonitorDelegate: AnyObject {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didRequestMoveIn direction: ZoneNavigator.Direction)
    func keyboardMonitorDidDisengage(_ monitor: KeyboardMonitor)
}

/// Listens for the zone-move hotkey (Control+Option+Arrow by default) via a
/// session-level `CGEventTap` and reports the requested direction. Unlike
/// ``DragMonitor`` this tap is active (not listen-only) so it can swallow a
/// matched chord and stop the arrow key from also reaching the focused app.
@MainActor
final class KeyboardMonitor: InputMonitor {
    weak var delegate: KeyboardMonitorDelegate?

    /// Modifiers that must all be held for the chord to fire.
    var requiredModifiers: CGEventFlags = [.maskControl, .maskAlternate]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// True once a move has shown the overlay, until the modifiers are released.
    /// Gates the disengage callback so it only fires for gestures we started.
    private var engaged = false

    var isRunning: Bool { eventTap != nil }

    /// Arrow key codes (`kVK_*`) mapped to a navigation direction.
    private static let directions: [Int64: ZoneNavigator.Direction] = [
        123: .left,   // kVK_LeftArrow
        124: .right,  // kVK_RightArrow
        125: .down,   // kVK_DownArrow
        126: .up,     // kVK_UpArrow
    ]

    /// Modifier bits we test against so stray device-dependent flags don't break
    /// the exact-match check.
    private static let modifierMask: CGEventFlags =
        [.maskControl, .maskAlternate, .maskCommand, .maskShift]

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

    /// Handles a key-down. Returns `true` when the chord matched and the event
    /// should be swallowed.
    fileprivate func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) -> Bool {
        // An active tap that the system disables stops swallowing the hotkey, so
        // a silent failure here is user-visible — log it as we re-arm.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Log.app.error("Keyboard tap disabled (\(type.rawValue, privacy: .public)) — re-enabling")
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }

        // Modifier changes are never consumed; we only watch them to learn when
        // the held hotkey is let go, so the overlay can be dismissed.
        if type == .flagsChanged {
            if engaged && !flags.isSuperset(of: requiredModifiers) {
                engaged = false
                delegate?.keyboardMonitorDidDisengage(self)
            }
            return false
        }

        guard type == .keyDown,
              flags.intersection(Self.modifierMask) == requiredModifiers,
              let direction = Self.directions[keyCode] else { return false }

        engaged = true
        Log.app.debug("Zone-move hotkey: \(String(describing: direction), privacy: .public)")
        delegate?.keyboardMonitor(self, didRequestMoveIn: direction)
        return true
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
