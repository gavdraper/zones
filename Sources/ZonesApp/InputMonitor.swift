import Foundation

/// A start/stoppable source of input gestures (mouse drags, hotkeys). Both
/// ``DragMonitor`` and ``KeyboardMonitor`` are installed once Accessibility is
/// granted and torn down on quit, so the two ways of snapping are never
/// half-enabled.
@MainActor
protocol InputMonitor: AnyObject {
    @discardableResult
    func start() -> Bool
    func stop()
    var isRunning: Bool { get }
}
