import CoreGraphics

/// Maps a zone's normalized frame onto a concrete display rectangle.
///
/// `displayBounds` and the returned frame share the same coordinate space; the
/// caller decides what that space is (this type performs no origin flipping).
/// Pass a top-left-origin rect in and you get a top-left-origin rect out.
///
/// A `gap` (in points) insets every placed window so neighbours don't touch.
/// Half the gap is taken from the work area and half from each window, which
/// yields a single uniform gap both between adjacent windows and at the screen
/// edges. A `gap` of `0` is a no-op.
public enum ZoneGeometry {

    /// The pixel frame of `zone` within `displayBounds`, inset by `gap`.
    public static func frame(for zone: Zone, in displayBounds: CGRect, gap: CGFloat = 0) -> CGRect {
        frame(forNormalized: zone.normalizedFrame, in: displayBounds, gap: gap)
    }

    /// The pixel frame of a normalized (`0...1`, top-left origin) rect within
    /// `displayBounds`, inset by `gap`.
    public static func frame(
        forNormalized normalized: CGRect, in displayBounds: CGRect, gap: CGFloat = 0
    ) -> CGRect {
        let half = gap / 2
        let work = displayBounds.insetBy(dx: half, dy: half)
        let mapped = CGRect(
            x: work.origin.x + normalized.origin.x * work.width,
            y: work.origin.y + normalized.origin.y * work.height,
            width: normalized.width * work.width,
            height: normalized.height * work.height
        )
        return nonNegative(mapped.insetBy(dx: half, dy: half))
    }

    /// Centers `size` within `displayBounds`, shrinking it to fit the gap-inset
    /// work area if it's larger. Used by size actions that preserve the window's
    /// current dimensions (e.g. "center") rather than resizing to a fraction.
    public static func centered(size: CGSize, in displayBounds: CGRect, gap: CGFloat = 0) -> CGRect {
        let half = gap / 2
        let work = displayBounds.insetBy(dx: half, dy: half)
        let fitted = CGSize(
            width: min(size.width, work.width),
            height: min(size.height, work.height)
        )
        return nonNegative(CGRect(
            x: work.midX - fitted.width / 2,
            y: work.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        ))
    }

    /// Clamps a rect's dimensions to zero so an over-large gap can't produce a
    /// negative (inverted) size.
    private static func nonNegative(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: max(0, rect.width),
            height: max(0, rect.height)
        )
    }
}
