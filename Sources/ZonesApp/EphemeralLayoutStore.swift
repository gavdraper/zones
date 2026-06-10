import ZonesCore

/// A non-persistent `LayoutStore` used as a last-resort fallback when the file
/// store can't be reached. The app stays usable for the session; changes simply
/// aren't written to disk.
///
/// `@unchecked Sendable` is safe here because the only owner, `LayoutLibrary`,
/// is `@MainActor`, so this store is never touched off the main thread.
final class EphemeralLayoutStore: LayoutStore, @unchecked Sendable {
    private var library: PersistedLibrary = .empty

    func load() throws -> PersistedLibrary { library }
    func save(_ library: PersistedLibrary) throws { self.library = library }
}
