import Foundation

/// A start/stoppable source of input gestures (mouse drags, hotkeys) that the
/// menu's "Snapping Enabled" toggle drives as a group. Both ``DragMonitor`` and
/// ``KeyboardMonitor`` are installed and torn down together so the two ways of
/// snapping are never half-enabled.
@MainActor
protocol InputMonitor: AnyObject {
    @discardableResult
    func start() -> Bool
    func stop()
    var isRunning: Bool { get }
}
