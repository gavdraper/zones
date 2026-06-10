/// A node in an editable grid's binary-split (BSP / guillotine) tree.
///
/// The tree partitions the unit square (`0...1`, top-left origin) with no gaps
/// or overlaps *by construction*: a `.leaf` is one cell, and a `.split` divides
/// its region into two children at `ratio` along `axis`. Leaves carry no
/// identity — concrete `Zone` ids are assigned only when the tree is flattened
/// (see `EditableGrid.zones()`), keeping the structure purely geometric.
public indirect enum GridNode: Equatable, Codable, Sendable {
    /// A single, indivisible cell.
    case leaf

    /// A region divided into `first` and `second` at `ratio` along `axis`.
    /// `ratio` is `first`'s fraction of the parent region (`0...1`).
    case split(axis: GridAxis, ratio: Double, first: GridNode, second: GridNode)
}
