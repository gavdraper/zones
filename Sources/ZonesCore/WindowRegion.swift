import CoreGraphics

/// A built-in window placement that needs no user-drawn layout: the standard
/// halves, quarters, maximize, and center actions familiar from Rectangle.
///
/// Most cases describe a fixed fraction of the display via ``normalizedFrame``
/// (0…1, top-left origin), reusing the same mapping as zones. ``center`` is the
/// exception: it preserves the window's current size and only repositions it, so
/// it has no normalized frame (callers handle it via
/// ``ZoneGeometry/centered(size:in:gap:)``).
public enum WindowRegion: CaseIterable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case maximize
    case center

    /// The fraction of the display this region occupies, or `nil` for ``center``
    /// (which keeps the window's existing size).
    public var normalizedFrame: CGRect? {
        switch self {
        case .leftHalf:           return CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf:          return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf:            return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf:         return CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .topLeftQuarter:     return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRightQuarter:    return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeftQuarter:  return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRightQuarter: return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .maximize:           return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .center:             return nil
        }
    }
}
