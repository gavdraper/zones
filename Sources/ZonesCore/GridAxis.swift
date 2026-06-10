/// The orientation of a split in an editable grid.
///
/// A split divides its region into a `first` and `second` child. The axis names
/// the direction the *divider line* runs across, which determines how the two
/// children are stacked:
///
/// - `.vertical`: a vertical divider line splits the region **left/right**;
///   `first` is the left child, `second` the right.
/// - `.horizontal`: a horizontal divider line splits the region **top/bottom**;
///   `first` is the top child, `second` the bottom (top-left origin, y grows down).
public enum GridAxis: Equatable, Codable, Sendable {
    case horizontal
    case vertical
}
