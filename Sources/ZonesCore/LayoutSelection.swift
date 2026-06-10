import Foundation

/// A stable, source-agnostic reference to the active layout that survives across
/// launches. Built-ins are referenced by name (they're defined in code); user
/// layouts by their persistent `UUID`.
public enum LayoutSelection: Equatable, Codable, Sendable {
    case builtin(name: String)
    case user(id: UUID)
}
