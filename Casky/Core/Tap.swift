import Foundation

/// A third-party Homebrew tap the user added, with the formulae and casks it
/// had when last fetched.
struct TapListing: Codable, Hashable, Identifiable, Sendable {
    /// Normalized `owner/repo` (see `Ref.parseTap`).
    let name: String
    let formulae: [String]
    let casks: [String]

    var id: String { name }

    var items: [Item] {
        formulae.compactMap { try? Ref(parsing: "\(name)/\($0)") }.map(Item.formula)
            + casks.compactMap { try? Ref(parsing: "\(name)/\($0)") }.map(Item.cask)
    }

    /// `https://github.com/owner/homebrew-repo`, where Homebrew clones it from.
    var repositoryURL: URL {
        let parts = name.split(separator: "/")
        return URL(string: "https://github.com/\(parts[0])/homebrew-\(parts[1])")!
    }

    /// Formula or cask names from a GitHub contents API listing of `Formula/`
    /// or `Casks/`: one `<name>.rb` file each.
    static func names(fromGitHubContents data: Data) throws -> [String] {
        try JSONDecoder().decode([Entry].self, from: data)
            .filter { $0.type == "file" && $0.name.hasSuffix(".rb") }
            .map { String($0.name.dropLast(3)) }
            .sorted()
    }

    private struct Entry: Decodable {
        let name: String
        let type: String
    }
}
