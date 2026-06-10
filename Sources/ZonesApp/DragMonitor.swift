import AppKit

/// High-level drag events emitted by ``DragMonitor``. Points are in Quartz/AX
/// (top-left) global coordinates.
@MainActor
protocol DragMonitorDelegate: AnyObject {
    func dragDidBegin(at point: CGPoint, modifierActive: Bool)
    func dragDidMove(to point: CGPoint, modifierActive: Bool)
    func dragDidEnd(at point: CGPoint, modifierActive: Bool)
}

/// Detects left-button window drags via a session-level `CGEventTap` and
/// reports them as begin/move/end gestures, along with whether the snap
/// modifier is held. It never mutates events (listen-only).
@MainActor
final class DragMonitor: InputMonitor {
    weak var delegate: DragMonitorDelegate?

    /// Modifier that arms snapping while dragging. Defaults to Shift, matching
    /// the FancyZones default.
    var modifierFlag: CGEventFlags = .maskShift

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDragging = false

    var isRunning: Bool { eventTap != nil }

    /// Installs the event tap on the main run loop. Requires Accessibility
    /// permission; returns `false` if the tap could not be created.
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: dragTapCallback,
            userInfo: refcon
        ) else {
            Log.drag.error("CGEvent.tapCreate returned nil — Accessibility not granted to this binary?")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        Log.drag.info("Event tap installed and enabled")
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
        isDragging = false
    }

    /// Called from the C tap callback on the main thread. Receives only the
    /// event's value-type fields so no non-`Sendable` `CGEvent` crosses the
    /// actor hop.
    fileprivate func handle(type: CGEventType, point: CGPoint, flags: CGEventFlags) {
        // The system disables a tap that runs long or is interrupted; re-arm it
        // and abandon any in-flight gesture so a stale overlay can't get stuck.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            isDragging = false
            return
        }

        let modifierActive = flags.contains(modifierFlag)

        switch type {
        case .leftMouseDragged:
            if isDragging {
                delegate?.dragDidMove(to: point, modifierActive: modifierActive)
            } else {
                isDragging = true
                Log.drag.info("Drag began at \(point.debugDescription, privacy: .public) modifier=\(modifierActive)")
                delegate?.dragDidBegin(at: point, modifierActive: modifierActive)
            }
        case .leftMouseUp:
            if isDragging {
                isDragging = false
                delegate?.dragDidEnd(at: point, modifierActive: modifierActive)
            }
        default:
            break
        }
    }
}

/// C-compatible tap callback. Hops onto the main actor (the tap is attached to
/// the main run loop, so we are already on the main thread) and forwards to the
/// owning monitor.
private func dragTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // The tap is installed on the main run loop, so this fires on the main
    // thread — the precondition makes that invariant fail loudly if the tap is
    // ever moved to another run loop, where `assumeIsolated` would be unsound.
    dispatchPrecondition(condition: .onQueue(.main))
    if let userInfo {
        let monitor = Unmanaged<DragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        let point = event.location
        let flags = event.flags
        MainActor.assumeIsolated {
            monitor.handle(type: type, point: point, flags: flags)
        }
    }
    return Unmanaged.passUnretained(event)
}
