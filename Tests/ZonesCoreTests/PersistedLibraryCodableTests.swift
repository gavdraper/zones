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

    @Test("Round-trips the gap value")
    func gapRoundTrips() throws {
        let library = PersistedLibrary(userLayouts: [], active: nil, gap: 12)
        #expect(try roundTrip(library) == library)
    }

    @Test("A file written before gaps existed decodes to a zero gap")
    func legacyFileHasZeroGap() throws {
        let legacy = Data(#"{"userLayouts":[]}"#.utf8)
        let library = try JSONDecoder().decode(PersistedLibrary.self, from: legacy)
        #expect(library.gap == 0)
        #expect(library.userLayouts.isEmpty)
        #expect(library.active == nil)
    }

    @Test("Round-trips the hotkey-hints flag")
    func hintsEnabledRoundTrips() throws {
        let library = PersistedLibrary(userLayouts: [], active: nil, gap: 0, hintsEnabled: false)
        #expect(try roundTrip(library) == library)
    }

    @Test("A file written before hints existed decodes to hints enabled")
    func legacyFileHasHintsEnabled() throws {
        let legacy = Data(#"{"userLayouts":[]}"#.utf8)
        let library = try JSONDecoder().decode(PersistedLibrary.self, from: legacy)
        #expect(library.hintsEnabled)
    }

    private func roundTrip(_ library: PersistedLibrary) throws -> PersistedLibrary {
        let data = try JSONEncoder().encode(library)
        return try JSONDecoder().decode(PersistedLibrary.self, from: data)
    }
}
