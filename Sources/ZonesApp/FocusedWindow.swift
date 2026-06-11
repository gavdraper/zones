import AppKit
import ApplicationServices

/// A thin wrapper over the Accessibility element of the frontmost app's focused
/// window, exposing just enough to reposition and resize it.
struct FocusedWindow {
    private let element: AXUIElement

    /// The focused window of the frontmost application, or `nil` if there isn't
    /// one (e.g. the desktop is active) or AX access is unavailable.
    static func current() -> FocusedWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &value
        )
        guard result == .success, let window = value,
              CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        return FocusedWindow(element: window as! AXUIElement)
    }

    /// The window's current frame in Quartz/AX (top-left) global coordinates,
    /// or `nil` if either attribute is unavailable.
    func frame() -> CGRect? {
        guard let origin = position(), let size = size() else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private func position() -> CGPoint? {
        guard let value = axValue(kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private func size() -> CGSize? {
        guard let value = axValue(kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    /// Reads an attribute and returns it as an `AXValue`, or `nil` if absent or
    /// not an `AXValue`.
    private func axValue(_ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    /// Snaps the window to `frame`, expressed in Quartz/AX (top-left) global
    /// coordinates.
    ///
    /// Apps frequently clamp a requested size against the window's *current*
    /// position: a window still sitting at its old (larger) location can't be
    /// resized in one shot without going off-screen, so the OS silently
    /// truncates the resize and the window stays taller or wider than the zone.
    /// We therefore move, size, move, then size again — re-applying the size
    /// once the window is already inside the zone — and read the frame back to
    /// confirm it landed. If it didn't, we retry; an app with a hard min/max
    /// size that won't budge between passes is logged and left as-is.
    func setFrame(_ frame: CGRect) {
        var previousSize: CGSize?
        for _ in 1...Self.maxFrameAttempts {
            setPosition(frame.origin)
            setSize(frame.size)
            setPosition(frame.origin)
            setSize(frame.size)

            guard let actual = self.frame() else { return }
            if actual.size.approximatelyEquals(frame.size, tolerance: Self.sizeTolerance) { return }

            // No movement since the last pass means the window won't honour the
            // size (hard app constraint, or an app that ignores AX sizing).
            if let previousSize, previousSize.approximatelyEquals(actual.size, tolerance: Self.sizeTolerance) {
                break
            }
            previousSize = actual.size
        }

        if let actual = self.frame() {
            Log.snap.warning(
                "Window resisted resize: wanted \(frame.size.debugDescription, privacy: .public), got \(actual.size.debugDescription, privacy: .public)"
            )
        }
    }

    /// Upper bound on convergence passes. Two passes suffice in the common
    /// position-clamps-size case; the extra margin covers stubborn apps.
    private static let maxFrameAttempts = 4

    /// Pixel slack when comparing the requested size to the realised one. Some
    /// apps snap to row/column increments, so an exact match isn't guaranteed.
    private static let sizeTolerance: CGFloat = 2

    private func setPosition(_ point: CGPoint) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        if result != .success {
            Log.snap.debug("setPosition failed: AXError \(result.rawValue)")
        }
    }

    private func setSize(_ size: CGSize) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        if result != .success {
            Log.snap.debug("setSize failed: AXError \(result.rawValue)")
        }
    }
}

private extension CGSize {
    /// Whether both dimensions are within `tolerance` points of `other`.
    func approximatelyEquals(_ other: CGSize, tolerance: CGFloat) -> Bool {
        abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}
