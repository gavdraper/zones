import CoreGraphics

/// Maps a zone's normalized frame onto a concrete display rectangle.
///
/// `displayBounds` and the returned frame share the same coordinate space; the
/// caller decides what that space is (this type performs no origin flipping).
/// Pass a top-left-origin rect in and you get a top-left-origin rect out.
public enum ZoneGeometry {

    /// The pixel frame of `zone` within `displayBounds`.
    public static func frame(for zone: Zone, in displayBounds: CGRect) -> CGRect {
        let normalized = zone.normalizedFrame
        return CGRect(
            x: displayBounds.origin.x + normalized.origin.x * displayBounds.width,
            y: displayBounds.origin.y + normalized.origin.y * displayBounds.height,
            width: normalized.width * displayBounds.width,
            height: normalized.height * displayBounds.height
        )
    }
}
