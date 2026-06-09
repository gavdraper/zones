import AppKit
import ZonesCore

/// Bridges AppKit's screen coordinates (bottom-left origin, y up) and the
/// Quartz/Accessibility global space (top-left origin, y down).
///
/// `CGEvent` mouse locations and the Accessibility API both report top-left
/// coordinates, while `NSScreen`/`NSWindow` use bottom-left. This type supplies
/// the live primary-screen height; the flip arithmetic itself lives in the
/// unit-tested ``CoordinateFlip``.
enum CoordinateSpace {

    /// Full height of the primary (zero-origin) screen — the axis the global
    /// flip is measured against (the global origin sits above the menu bar, so
    /// this must be `frame.height`, not `visibleFrame.height`).
    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// AppKit (bottom-left) rect → Quartz/AX (top-left) rect.
    static func quartz(fromAppKit rect: CGRect) -> CGRect {
        CoordinateFlip.flip(rect, referenceHeight: primaryHeight)
    }

    /// Quartz/AX (top-left) rect → AppKit (bottom-left) rect.
    static func appKit(fromQuartz rect: CGRect) -> CGRect {
        CoordinateFlip.flip(rect, referenceHeight: primaryHeight)
    }
}
