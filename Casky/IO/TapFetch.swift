import Foundation

/// Lists a tap's formulae and casks from GitHub without tapping it.
/// Formulae live in `Formula/` or, in older taps such as charmbracelet/tap,
/// at the repository root; casks live in `Casks/`.
// ponytail: contents API, unauthenticated (60 requests/hour, 2-3 per tap).
// Taps that shard files into subfolders show up partially; use the git trees
// API if a real tap needs it.
struct TapFetch: Sendable {
    var session: URLSession = .shared

    func fetch(_ tap: String) async throws -> TapListing {
        let listing = TapListing(name: tap, formulae: [], casks: [])
        async let formulae = names(in: "Formula", of: listing)
        async let casks = names(in: "Casks", of: listing)
        var (foundFormulae, foundCasks) = try await (formulae, casks)
        if foundFormulae == nil {
            foundFormulae = try await names(in: "", of: listing).flatMap { $0.isEmpty ? nil : $0 }
        }
        guard foundFormulae != nil || foundCasks != nil else { throw TapError.notFound(tap) }
        return TapListing(name: tap, formulae: foundFormulae ?? [], casks: foundCasks ?? [])
    }

    /// nil when the folder doesn't exist.
    private func names(in folder: String, of tap: TapListing) async throws -> [String]? {
        let repo = tap.repositoryURL.path() // /owner/homebrew-repo
        let url = URL(string: "https://api.github.com/repos\(repo)/contents/\(folder)")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: return try TapListing.names(fromGitHubContents: data)
        case 404: return nil
        case 403, 429: throw TapError.rateLimited
        case let status: throw FetchError.http(url: url, status: status)
        }
    }
}

enum TapError: Error, Equatable {
    case notFound(String)
    case rateLimited
}
