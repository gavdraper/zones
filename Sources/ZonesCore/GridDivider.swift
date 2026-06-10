import CoreGraphics

/// A flattened descriptor of one split's divider line, produced for the editor
/// to hit-test and drag.
///
/// `bounds` is the divider line in the unit square (`0...1`, top-left origin),
/// expressed as a zero-thickness rect: a `.vertical` divider has `width == 0`
/// and spans its region's height; a `.horizontal` divider has `height == 0` and
/// spans its width. The view inflates it into a draggable band at render time,
/// so the geometry here stays resolution-independent.
public struct GridDivider: Identifiable, Equatable, Sendable {
    /// The path of the `split` node this divider belongs to.
    public let id: GridPath
    public let axis: GridAxis
    public let ratio: Double
    public let bounds: CGRect

    public init(id: GridPath, axis: GridAxis, ratio: Double, bounds: CGRect) {
        self.id = id
        self.axis = axis
        self.ratio = ratio
        self.bounds = bounds
    }
}
