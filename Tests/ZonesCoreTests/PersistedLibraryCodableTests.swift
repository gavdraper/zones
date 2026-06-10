import Testing
import Foundation
@testable import ZonesCore

@Suite("Persisted library — coding")
struct PersistedLibraryCodableTests {

    @Test("Round-trips with a built-in selection")
    func builtinSelection() throws {
        let library = PersistedLibrary(
            userLayouts: [],
            active: .builtin(name: "3 Columns")
        )
        #expect(try roundTrip(library) == library)
    }

    @Test("Round-trips with a user selection and custom layouts")
    func userSelection() throws {
        let layout = UserLayout(
            name: "Coding",
            grid: EditableGrid.single.splitting(.root, axis: .vertical, at: 0.6)
        )
        let library = PersistedLibrary(userLayouts: [layout], active: .user(id: layout.id))
        #expect(try roundTrip(library) == library)
    }

    @Test("Round-trips with no active selection")
    func noSelection() throws {
        #expect(try roundTrip(PersistedLibrary.empty) == .empty)
    }

    private func roundTrip(_ library: PersistedLibrary) throws -> PersistedLibrary {
        let data = try JSONEncoder().encode(library)
        return try JSONDecoder().decode(PersistedLibrary.self, from: data)
    }
}
