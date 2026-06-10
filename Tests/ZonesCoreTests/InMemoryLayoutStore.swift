import Foundation
@testable import ZonesCore

/// In-memory `LayoutStore` fake for exercising `LayoutLibrary` without touching
/// the filesystem. Records how many times it was saved and can be primed to
/// throw on load.
final class InMemoryLayoutStore: LayoutStore, @unchecked Sendable {
    private(set) var saved: PersistedLibrary
    private(set) var saveCount = 0
    var loadError: Error?

    init(_ initial: PersistedLibrary = .empty) {
        self.saved = initial
    }

    func load() throws -> PersistedLibrary {
        if let loadError { throw loadError }
        return saved
    }

    func save(_ library: PersistedLibrary) throws {
        saved = library
        saveCount += 1
    }
}
