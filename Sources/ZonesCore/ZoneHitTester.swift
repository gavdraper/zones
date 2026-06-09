import CoreGraphics

/// Resolves which zone a point falls into, used to decide where a dragged
/// window will snap.
public enum ZoneHitTester {

    /// The zone under `point`, or `nil` if the point lies outside every zone.
    ///
    /// `point` and `displayBounds` must be in the same coordinate space. When
    /// zones overlap, the smallest-area match wins so that a nested/priority
    /// zone takes precedence over a larger one underneath it.
    public static func zone(
        at point: CGPoint,
        layout: ZoneLayout,
        displayBounds: CGRect
    ) -> Zone? {
        layout.zones
            .filter { ZoneGeometry.frame(for: $0, in: displayBounds).contains(point) }
            .min { lhs, rhs in
                area(of: lhs, in: displayBounds) < area(of: rhs, in: displayBounds)
            }
    }

    private static func area(of zone: Zone, in displayBounds: CGRect) -> CGFloat {
        let frame = ZoneGeometry.frame(for: zone, in: displayBounds)
        return frame.width * frame.height
    }
}
