import Foundation

/// One JSON file of user data in `~/Library/Application Support/casky/`.
struct JSONFile<Value: Codable>: Sendable {
    let file: URL

    /// No file yet means `empty`. An unreadable file is an error: it holds the
    /// user's data, so the caller must not overwrite it.
    func load(empty: Value) throws -> Value {
        guard FileManager.default.fileExists(atPath: file.path) else { return empty }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: file))
    }

    func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: file, options: .atomic)
    }
}
