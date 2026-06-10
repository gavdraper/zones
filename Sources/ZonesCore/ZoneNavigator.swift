import CoreGraphics

/// Resolves directional moves between zones, used to step the focused window
/// between zones with the keyboard.
///
/// Adjacency is computed purely from zones' normalized frames (top-left origin,
/// y grows down), so it is independent of any display. A neighbour in a given
/// direction is the nearest zone on that side that also overlaps the source
/// zone on the perpendicular axis — this keeps grid moves orthogonal and never
/// jumps diagonally.
public enum ZoneNavigator {

    public enum Direction: Sendable {
        case left, right, up, down
    }

    /// Small tolerance for normalized-coordinate comparisons.
    private static let epsilon: CGFloat = 1e-6

    /// The zone the window currently occupies — the one it intersects most.
    /// Returns `nil` if the window overlaps no zone.
    ///
    /// `windowFrame` and `displayBounds` must share a coordinate space.
    public static func currentZone(
        forWindowFrame windowFrame: CGRect,
        layout: ZoneLayout,
        displayBounds: CGRect
    ) -> Zone? {
        layout.zones
            .map { (zone: $0, overlap: overlapArea($0, windowFrame, displayBounds)) }
            .filter { $0.overlap > 0 }
            .max { $0.overlap < $1.overlap }
            .map(\.zone)
    }

    /// The zone adjacent to `zone` in `direction`, or `nil` at the layout edge.
    public static func adjacentZone(
        from zone: Zone,
        direction: Direction,
        in layout: ZoneLayout
    ) -> Zone? {
        let source = zone.normalizedFrame

        // A neighbour must be on the `direction` side *and* overlap the source on
        // the perpendicular axis, so moves stay orthogonal and never jump
        // diagonally. With no aligned neighbour the move is a no-op (`nil`).
        let aligned = layout.zones.filter {
            $0.id != zone.id
                && isAhead($0.normalizedFrame, of: source, direction)
                && overlapsPerpendicular($0.normalizedFrame, source, direction)
        }

        return aligned.min { distance($0.normalizedFrame, source, direction) < distance($1.normalizedFrame, source, direction) }
    }

    /// The zone whose centre is closest to `point`, used to pull a window that
    /// sits in no zone into the grid on the first keypress.
    ///
    /// `point` and `displayBounds` must share a coordinate space.
    public static func nearestZone(
        to point: CGPoint,
        layout: ZoneLayout,
        displayBounds: CGRect
    ) -> Zone? {
        layout.zones.min { lhs, rhs in
            centerDistanceSquared(lhs, point, displayBounds) < centerDistanceSquared(rhs, point, displayBounds)
        }
    }

    // MARK: - Geometry helpers

    private static func overlapArea(_ zone: Zone, _ windowFrame: CGRect, _ displayBounds: CGRect) -> CGFloat {
        let frame = ZoneGeometry.frame(for: zone, in: displayBounds)
        let intersection = frame.intersection(windowFrame)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private static func centerDistanceSquared(_ zone: Zone, _ point: CGPoint, _ displayBounds: CGRect) -> CGFloat {
        let frame = ZoneGeometry.frame(for: zone, in: displayBounds)
        let dx = frame.midX - point.x
        let dy = frame.midY - point.y
        return dx * dx + dy * dy
    }

    /// Whether `candidate` lies on the `direction` side of `source` by centre.
    private static func isAhead(_ candidate: CGRect, of source: CGRect, _ direction: Direction) -> Bool {
        switch direction {
        case .left:  return candidate.midX < source.midX - epsilon
        case .right: return candidate.midX > source.midX + epsilon
        case .up:    return candidate.midY < source.midY - epsilon
        case .down:  return candidate.midY > source.midY + epsilon
        }
    }

    /// Whether `candidate` overlaps `source` on the axis perpendicular to the move.
    private static func overlapsPerpendicular(_ candidate: CGRect, _ source: CGRect, _ direction: Direction) -> Bool {
        switch direction {
        case .left, .right:
            return candidate.minY < source.maxY - epsilon && candidate.maxY > source.minY + epsilon
        case .up, .down:
            return candidate.minX < source.maxX - epsilon && candidate.maxX > source.minX + epsilon
        }
    }

    /// Ranks neighbours lexicographically: nearest along the move axis first,
    /// then nearest on the perpendicular axis to break ties between stacked
    /// candidates. Comparing the pair directly avoids any magnitude assumption a
    /// weighted sum would bake in.
    private static func distance(_ candidate: CGRect, _ source: CGRect, _ direction: Direction) -> (axial: CGFloat, perpendicular: CGFloat) {
        switch direction {
        case .left, .right:
            return (abs(candidate.midX - source.midX), abs(candidate.midY - source.midY))
        case .up, .down:
            return (abs(candidate.midY - source.midY), abs(candidate.midX - source.midX))
        }
    }
}
