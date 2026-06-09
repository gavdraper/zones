import CoreGraphics

/// Pure vertical flip between a bottom-left origin coordinate space (AppKit) and
/// a top-left origin space (Quartz / Accessibility), measured against a fixed
/// reference height.
///
/// This is the single most error-prone calculation in a window manager, so it
/// lives here — free of `NSScreen` — to be exhaustively unit-tested. The
/// transform is an involution: applying it twice with the same `referenceHeight`
/// returns the original rect.
public enum CoordinateFlip {

    /// Flips `rect`'s vertical axis around `referenceHeight`.
    ///
    /// `referenceHeight` must be the *full* height of the primary display (the
    /// global coordinate origin sits above the menu bar), even when `rect` is a
    /// menu-bar-excluding visible frame.
    public static func flip(_ rect: CGRect, referenceHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: referenceHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
