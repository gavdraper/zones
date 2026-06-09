import CoreGraphics

/// A single rectangular zone within a display.
///
/// The frame is stored in *normalized* coordinates — each value is a fraction
/// (`0...1`) of the display, with a top-left origin (x grows right, y grows
/// down). Storing zones normalized keeps layouts resolution- and
/// display-independent: the same layout maps onto a laptop panel or a 4K
/// monitor without change.
public struct Zone: Identifiable, Equatable, Codable, Sendable {
    public let id: Int
    public let normalizedFrame: CGRect

    public init(id: Int, normalizedFrame: CGRect) {
        self.id = id
        self.normalizedFrame = normalizedFrame
    }
}
