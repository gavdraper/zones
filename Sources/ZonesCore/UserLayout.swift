import Foundation

/// A user-created layout: a stable identity, a display name, and the editable
/// grid that is its source of truth. The flattened `[Zone]` is always derived
/// from `grid` (never stored), so the snappable layout can't drift from what the
/// editor shows.
public struct UserLayout: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var grid: EditableGrid

    public init(id: UUID = UUID(), name: String, grid: EditableGrid) {
        self.id = id
        self.name = name
        self.grid = grid
    }

    /// The layout flattened for snapping/overlay.
    public func asZoneLayout() -> ZoneLayout {
        grid.layout(named: name)
    }
}
