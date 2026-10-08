import Foundation

/// What casky shows for one installable item.
struct CatalogEntry: Codable, Hashable, Identifiable, Sendable {
    let item: Item
    let title: String
    let summary: String?
    let homepage: URL?
    /// Installs over the last year from Homebrew analytics; 0 when unknown.
    let installs: Int
    /// Heuristic: the cask ships a pkg or installer, which usually runs `sudo`.
    let needsAdmin: Bool
    /// The `.app` a cask puts in /Applications, for showing its real icon.
    var appBundleName: String? = nil
    /// Artwork published with the item (App Store apps).
    var iconURL: URL? = nil
    /// Latest version Homebrew offers (casks), for spotting updates of apps
    /// installed outside Homebrew.
    var version: String? = nil
    /// Casks Homebrew won't install alongside this one, usually other
    /// versions of the same app (`ghostty` and `ghostty@tip`).
    var conflicts: [Item]? = nil

    var id: Item { item }
}

/// The searchable Homebrew catalog (formulae and casks). App Store results
/// come from a live search instead; see `AppStoreSearch`.
struct Catalog: Sendable {
    let entries: [CatalogEntry]
    private let index: [Item: CatalogEntry]
    private let searchKeys: [SearchKey]

    init(entries: [CatalogEntry]) {
        self.entries = entries
        index = Dictionary(entries.map { ($0.item, $0) }, uniquingKeysWith: { first, _ in first })
        searchKeys = entries.map(SearchKey.init)
    }

    func entry(for item: Item) -> CatalogEntry? { index[item] }

    /// The other versions Homebrew offers of a core formula: `node`,
    /// `node@22`, `node@20`, newest first after the unversioned one.
    func versions(of item: Item) -> [Item] {
        guard case .formula(let ref) = item, ref.tap == nil else { return [] }
        let base = ref.name.split(separator: "@").first.map(String.init) ?? ref.name
        let found = entries.compactMap { entry -> Ref? in
            guard case .formula(let other) = entry.item, other.tap == nil,
                  other.name == base || other.name.hasPrefix(base + "@") else { return nil }
            return other
        }
        guard found.count > 1 else { return [] }
        return found.sorted { left, right in
            if left.name == base { return true }
            if right.name == base { return false }
            return left.name.compare(right.name, options: .numeric) == .orderedDescending
        }.map(Item.formula)
    }

    var adminItems: Set<Item> { Set(entries.lazy.filter(\.needsAdmin).map(\.item)) }

    /// Ranked by match quality (exact, prefix, substring of name, then
    /// substring of description), then by popularity. An empty query lists
    /// the most popular entries.
    /// `limit` nil returns every match.
    func search(_ query: String, kind: Item.Kind? = nil, limit: Int? = 200) -> [CatalogEntry] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        var hits: [(rank: Int, entry: CatalogEntry)] = []
        for (key, entry) in zip(searchKeys, entries) where kind == nil || entry.item.kind == kind {
            if let rank = key.rank(needle) { hits.append((rank, entry)) }
        }
        hits.sort {
            ($0.rank, -$0.entry.installs, $0.entry.title) < ($1.rank, -$1.entry.installs, $1.entry.title)
        }
        return hits.prefix(limit ?? hits.count).map(\.entry)
    }

    private struct SearchKey: Sendable {
        let names: [String]
        let summary: String

        init(_ entry: CatalogEntry) {
            let token = switch entry.item {
            case .formula(let ref), .cask(let ref): ref.name
            case .mas(_, let name): name.lowercased()
            }
            names = [token, entry.title.lowercased()]
            summary = entry.summary?.lowercased() ?? ""
        }

        func rank(_ needle: String) -> Int? {
            if needle.isEmpty { return 0 }
            if names.contains(needle) { return 0 }
            if names.contains(where: { $0.hasPrefix(needle) }) { return 1 }
            if names.contains(where: { $0.contains(needle) }) { return 2 }
            if summary.contains(needle) { return 3 }
            return nil
        }
    }
}

// MARK: - Homebrew API decoding

extension Catalog {
    /// Decodes `formulae.brew.sh` API payloads. Analytics are optional: without
    /// them everything still works, ranked by name only.
    static func decodeHomebrew(
        casks: Data,
        formulae: Data,
        caskInstalls: Data?,
        formulaInstalls: Data?
    ) throws -> [CatalogEntry] {
        let decoder = JSONDecoder()
        let caskCounts = caskInstalls.map { Analytics.counts($0, key: "cask") } ?? [:]
        let formulaCounts = formulaInstalls.map { Analytics.counts($0, key: "formula") } ?? [:]

        let formulaEntries = try decoder.decode([RawFormula].self, from: formulae).compactMap { raw -> CatalogEntry? in
            guard !raw.deprecated, !raw.disabled, let ref = try? Ref(parsing: raw.name) else { return nil }
            return CatalogEntry(
                item: .formula(ref), title: raw.name, summary: raw.desc,
                homepage: raw.homepage.flatMap(URL.init(string:)),
                installs: formulaCounts[raw.name] ?? 0, needsAdmin: false
            )
        }
        let rawCasks = try decoder.decode([RawCask].self, from: casks).filter { !$0.deprecated && !$0.disabled }
        // Versions of one app share a name ("Ghostty"); say which is which.
        let names = Dictionary(grouping: rawCasks, by: { $0.name?.first ?? $0.token }).filter { $0.value.count > 1 }
        let caskEntries = rawCasks.compactMap { raw -> CatalogEntry? in
            guard let ref = try? Ref(parsing: raw.token) else { return nil }
            var title = raw.name?.first ?? raw.token
            if names[title] != nil, let variant = raw.token.split(separator: "@", maxSplits: 1).dropFirst().first {
                title += " (\(variant))"
            }
            return CatalogEntry(
                item: .cask(ref), title: title, summary: raw.desc,
                homepage: raw.homepage.flatMap(URL.init(string:)),
                installs: caskCounts[raw.token] ?? 0,
                needsAdmin: raw.artifacts.contains { !$0.keys.isDisjoint(with: ["pkg", "installer"]) },
                appBundleName: raw.artifacts.lazy.compactMap(\.appName).first,
                version: raw.version,
                conflicts: raw.conflicts_with?.cask?.compactMap { try? Item.cask(Ref(parsing: $0)) }
            )
        }
        return formulaEntries + caskEntries
    }

    private struct RawFormula: Decodable {
        let name: String
        let desc: String?
        let homepage: String?
        let deprecated: Bool
        let disabled: Bool
    }

    private struct RawCask: Decodable {
        let token: String
        let version: String?
        let name: [String]?
        let desc: String?
        let homepage: String?
        let deprecated: Bool
        let disabled: Bool
        let artifacts: [Artifact]
        let conflicts_with: Conflicts?
        struct Conflicts: Decodable { let cask: [String]? }
    }

    /// The artifact kinds (`app`, `pkg`, `installer`, ...) and, for `app`,
    /// the installed bundle name. Other payloads vary per kind and are skipped.
    private struct Artifact: Decodable {
        let keys: Set<String>
        let appName: String?

        init(from decoder: Decoder) throws {
            let container = try? decoder.container(keyedBy: AnyKey.self)
            keys = Set(container?.allKeys.map(\.stringValue) ?? [])
            // `"app": ["Source.app"]` or `["Source.app", {"target": "Installed.app"}]`.
            let parts = try? container?.decode([AppPart].self, forKey: AnyKey(stringValue: "app"))
            appName = parts.flatMap { parts in
                parts.lazy.compactMap(\.target).first ?? parts.lazy.compactMap(\.source).first
            }
        }
    }

    private struct AppPart: Decodable {
        let source: String?
        let target: String?

        init(from decoder: Decoder) throws {
            if let name = try? decoder.singleValueContainer().decode(String.self) {
                source = name
                target = nil
            } else {
                source = nil
                target = try decoder.container(keyedBy: AnyKey.self).decodeIfPresent(String.self, forKey: AnyKey(stringValue: "target"))
            }
        }
    }

    private struct AnyKey: CodingKey {
        let stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    private enum Analytics {
        /// `{"items": [{"cask": "firefox", "count": "1,234"}, ...]}`
        static func counts(_ data: Data, key: String) -> [String: Int] {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = object["items"] as? [[String: Any]] else { return [:] }
            var counts: [String: Int] = [:]
            for item in items {
                guard let name = item[key] as? String else { continue }
                if let count = item["count"] as? String {
                    counts[name] = Int(count.replacingOccurrences(of: ",", with: ""))
                } else if let count = item["count"] as? Int {
                    counts[name] = count
                }
            }
            return counts
        }
    }
}

// MARK: - App Store

/// Live App Store search via the public iTunes Search API.
enum AppStoreSearch {
    static func url(for term: String) -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "entity", value: "macSoftware"),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "term", value: term),
        ]
        return components.url!
    }

    /// Apple's chart of top free Mac apps.
    static let topFreeURL = URL(string: "https://itunes.apple.com/us/rss/topfreemacapps/limit=50/json")!

    /// Ids from the chart feed, in chart order.
    static func chartIDs(_ data: Data) throws -> [Int] {
        try JSONDecoder().decode(Chart.self, from: data).feed.entry.compactMap { Int($0.id.attributes.id) }
    }

    /// One lookup for many ids; results come back in the search format.
    static func lookupURL(ids: [Int]) -> URL {
        URL(string: "https://itunes.apple.com/lookup?id=\(ids.map(String.init).joined(separator: ","))")!
    }

    private struct Chart: Decodable {
        let feed: Feed
        struct Feed: Decodable { let entry: [Entry] }
        struct Entry: Decodable { let id: ID }
        struct ID: Decodable {
            let attributes: Attributes
            struct Attributes: Decodable {
                let id: String
                enum CodingKeys: String, CodingKey { case id = "im:id" }
            }
        }
    }

    /// Keeps Mac apps only: the API also returns iPad apps for `macSoftware`
    /// queries, which `mas` cannot install.
    static func decode(_ data: Data) throws -> [CatalogEntry] {
        try JSONDecoder().decode(Response.self, from: data).results.compactMap { app in
            guard app.kind == "mac-software" else { return nil }
            return CatalogEntry(
                item: .mas(id: app.trackId, name: app.trackName), title: app.trackName,
                summary: app.description.flatMap { $0.split(separator: "\n").first.map(String.init) },
                homepage: app.trackViewUrl.flatMap(URL.init(string:)),
                installs: 0, needsAdmin: false,
                appBundleName: "\(app.trackName).app",
                iconURL: (app.artworkUrl512 ?? app.artworkUrl100).flatMap(URL.init(string:))
            )
        }
    }

    private struct Response: Decodable { let results: [App] }

    private struct App: Decodable {
        let trackId: Int
        let trackName: String
        let kind: String?
        let description: String?
        let trackViewUrl: String?
        let artworkUrl512: String?
        let artworkUrl100: String?
    }
}
