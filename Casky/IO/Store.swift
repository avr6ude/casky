import Foundation

/// Saved setups in `~/Library/Application Support/casky/setups.json`.
struct SetupStore: Sendable {
    var file: URL = URL.applicationSupportDirectory.appending(path: "casky/setups.json")

    /// No file yet means no setups. An unreadable file is an error: it holds
    /// the user's data, so the caller must not overwrite it.
    func load() throws -> [SavedSetup] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([SavedSetup].self, from: Data(contentsOf: file))
    }

    func save(_ setups: [SavedSetup]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(setups).write(to: file, options: .atomic)
    }
}
