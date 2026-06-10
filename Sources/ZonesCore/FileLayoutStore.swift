import Foundation

/// A `LayoutStore` backed by a single JSON file. The directory is injected, so
/// tests point it at a temp directory while the app uses Application Support.
///
/// Writes are atomic (`Data.WritingOptions.atomic` writes to a temp file and
/// renames), so a crash mid-save can't corrupt an existing library. A missing
/// file loads as `.empty`; a *corrupt* file surfaces a decode error rather than
/// silently discarding the user's layouts.
public struct FileLayoutStore: LayoutStore {
    private let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("library.json")
    }

    /// `~/Library/Application Support/Zones`, creating it if needed.
    public static func defaultDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return base.appendingPathComponent("Zones", isDirectory: true)
    }

    /// A store rooted at the standard Application Support directory.
    public static func standard() throws -> FileLayoutStore {
        FileLayoutStore(directory: try defaultDirectory())
    }

    public func load() throws -> PersistedLibrary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PersistedLibrary.self, from: data)
    }

    public func save(_ library: PersistedLibrary) throws {
        try createDirectoryIfNeeded()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try data.write(to: fileURL, options: .atomic)
    }

    private func createDirectoryIfNeeded() throws {
        let directory = fileURL.deletingLastPathComponent()
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
