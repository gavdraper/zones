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
    /// coordinates. Position is applied before and after sizing because some
    /// apps clamp one against the other on the first pass.
    func setFrame(_ frame: CGRect) {
        setPosition(frame.origin)
        setSize(frame.size)
        setPosition(frame.origin)
    }

    private func setPosition(_ point: CGPoint) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func setSize(_ size: CGSize) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }
}
