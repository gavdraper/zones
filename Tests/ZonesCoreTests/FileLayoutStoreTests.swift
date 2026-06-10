import Testing
import Foundation
@testable import ZonesCore

@Suite("File layout store")
struct FileLayoutStoreTests {

    @Test("Saving then loading round-trips the library")
    func saveLoadRoundTrip() throws {
        try withTemporaryDirectory { directory in
            let store = FileLayoutStore(directory: directory)
            let layout = UserLayout(
                name: "Work",
                grid: EditableGrid.single.splitting(.root, axis: .horizontal, at: 0.5)
            )
            let library = PersistedLibrary(userLayouts: [layout], active: .user(id: layout.id))

            try store.save(library)
            let loaded = try store.load()
            #expect(loaded == library)
        }
    }

    @Test("Loading an absent file yields an empty library")
    func absentFileIsEmpty() throws {
        try withTemporaryDirectory { directory in
            let store = FileLayoutStore(directory: directory)
            let loaded = try store.load()
            #expect(loaded == .empty)
        }
    }

    @Test("Loading a corrupt file surfaces an error instead of discarding data")
    func corruptFileThrows() throws {
        try withTemporaryDirectory { directory in
            let store = FileLayoutStore(directory: directory)
            try store.save(.empty)   // creates the directory + file
            try "{ not valid json".write(
                to: directory.appendingPathComponent("library.json"), atomically: true, encoding: .utf8
            )
            #expect(throws: (any Error).self) { try store.load() }
        }
    }

    @Test("Saving creates the directory if it does not exist")
    func createsDirectory() throws {
        try withTemporaryDirectory { directory in
            let nested = directory.appendingPathComponent("does/not/exist/yet")
            let store = FileLayoutStore(directory: nested)
            try store.save(.empty)
            let loaded = try store.load()
            #expect(loaded == .empty)
        }
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZonesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
