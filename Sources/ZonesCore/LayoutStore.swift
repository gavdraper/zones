/// Persistence boundary for the layout library. Abstracting it (rather than
/// reaching for the filesystem directly) lets `LayoutLibrary` be unit-tested
/// against an in-memory fake and keeps the storage mechanism swappable.
public protocol LayoutStore: Sendable {
    /// Loads the persisted library, returning `.empty` when nothing is stored yet.
    func load() throws -> PersistedLibrary

    /// Persists `library`, replacing any prior contents.
    func save(_ library: PersistedLibrary) throws
}
