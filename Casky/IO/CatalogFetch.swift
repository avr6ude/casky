import Foundation

/// Downloads the Homebrew catalog and keeps a trimmed copy on disk, so launch
/// is instant and offline-capable; the caller refreshes in the background
/// once the copy is stale.
struct CatalogFetch: Sendable {
    var session: URLSession = .shared
    var cacheFile: URL = URL.cachesDirectory.appending(path: "casky/catalog.json")
    var maxAge: TimeInterval = 24 * 60 * 60

    struct Cached: Sendable {
        let catalog: Catalog
        let fetchedAt: Date
        let isStale: Bool
    }

    /// The cache is disposable: a missing or unreadable file means "fetch
    /// again", not an error.
    func cached(now: Date = .now) -> Cached? {
        guard let data = try? Data(contentsOf: cacheFile),
              let file = try? JSONDecoder().decode(CacheFile.self, from: data) else { return nil }
        return Cached(
            catalog: Catalog(entries: file.entries),
            fetchedAt: file.fetchedAt,
            isStale: now.timeIntervalSince(file.fetchedAt) > maxAge
        )
    }

    /// Fetches formulae and casks (required) plus install analytics (optional:
    /// without them search still works, ranked by name), then rewrites the cache.
    func refresh(now: Date = .now) async throws -> Catalog {
        async let casks = download(Self.casksURL)
        async let formulae = download(Self.formulaeURL)
        async let caskInstalls = try? download(Self.caskInstallsURL)
        async let formulaInstalls = try? download(Self.formulaInstallsURL)

        let entries = try Catalog.decodeHomebrew(
            casks: try await casks,
            formulae: try await formulae,
            caskInstalls: await caskInstalls,
            formulaInstalls: await formulaInstalls
        )
        try store(entries, fetchedAt: now)
        return Catalog(entries: entries)
    }

    func searchAppStore(_ term: String) async throws -> [CatalogEntry] {
        try AppStoreSearch.decode(try await download(AppStoreSearch.url(for: term)))
    }

    func store(_ entries: [CatalogEntry], fetchedAt: Date) throws {
        try FileManager.default.createDirectory(at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(CacheFile(fetchedAt: fetchedAt, entries: entries)).write(to: cacheFile, options: .atomic)
    }

    private func download(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw FetchError.http(url: url, status: status) }
        return data
    }

    private struct CacheFile: Codable {
        let fetchedAt: Date
        let entries: [CatalogEntry]
    }

    private static let casksURL = URL(string: "https://formulae.brew.sh/api/cask.json")!
    private static let formulaeURL = URL(string: "https://formulae.brew.sh/api/formula.json")!
    private static let caskInstallsURL = URL(string: "https://formulae.brew.sh/api/analytics/cask-install/365d.json")!
    private static let formulaInstallsURL = URL(string: "https://formulae.brew.sh/api/analytics/install-on-request/365d.json")!
}

enum FetchError: Error, Equatable {
    case http(url: URL, status: Int)
}
