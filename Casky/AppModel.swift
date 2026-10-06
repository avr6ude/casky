import Foundation
import Observation

/// Owns everything the window shows: catalog, installed state, kits and the
/// current selection. Views read it; I/O goes through `CatalogFetch` and
/// `Homebrew`.
@MainActor @Observable
final class AppModel {
    enum CatalogState {
        case loading
        case ready(Catalog)
        case failed(String)
    }

    private(set) var catalogState: CatalogState = .loading {
        didSet { catalogVersion += 1 }
    }
    /// Bumps whenever the catalog changes, so views can re-run their searches.
    private(set) var catalogVersion = 0
    /// True while a background refresh runs on top of a usable cached catalog.
    private(set) var isRefreshingCatalog = false
    private(set) var catalogRefreshError: String?

    private(set) var installed = InstalledState()
    private(set) var installedError: String?
    let homebrew: Homebrew?

    let kits: [Kit]

    private(set) var selection: [Item] = []
    private var selectedSet: Set<Item> = []

    private let fetch: CatalogFetch
    /// App Store results seen so far, so selected App Store items keep their
    /// details. Bounded by what the user searched for.
    private var appStoreEntries: [Item: CatalogEntry] = [:]
    private var appStoreQueries: [String: [CatalogEntry]] = [:]

    init(fetch: CatalogFetch = CatalogFetch(), homebrew: Homebrew? = Homebrew(), kits: [Kit] = AppModel.bundledKits()) {
        self.fetch = fetch
        self.homebrew = homebrew
        self.kits = kits
    }

    var catalog: Catalog? {
        if case .ready(let catalog) = catalogState { catalog } else { nil }
    }

    // MARK: Loading

    /// Cached catalog first for an instant launch, then a background refresh
    /// when it is missing or stale.
    func start() async {
        async let installed: Void = refreshInstalled()
        let fetch = fetch
        let cached = await Task.detached { fetch.cached() }.value
        if let cached {
            catalogState = .ready(cached.catalog)
            if cached.isStale { await refreshCatalog() }
        } else {
            await refreshCatalog()
        }
        await installed
    }

    func refreshCatalog() async {
        guard !isRefreshingCatalog else { return }
        isRefreshingCatalog = true
        defer { isRefreshingCatalog = false }
        do {
            catalogState = .ready(try await fetch.refresh())
            catalogRefreshError = nil
        } catch {
            // With a cached catalog the app keeps working; say the refresh failed.
            if catalog == nil {
                catalogState = .failed(error.localizedDescription)
            } else {
                catalogRefreshError = error.localizedDescription
            }
        }
    }

    func refreshInstalled() async {
        guard let homebrew else { return }
        do {
            installed = try await homebrew.installedState()
            installedError = nil
        } catch {
            installedError = Self.describe(error)
        }
    }

    // MARK: Entries

    func entry(for item: Item) -> CatalogEntry? {
        if case .mas(let id, let name) = item {
            return appStoreEntries[item]
                ?? CatalogEntry(item: item, title: name, summary: nil, homepage: URL(string: "https://apps.apple.com/app/id\(id)"), installs: 0, needsAdmin: false)
        }
        return catalog?.entry(for: item)
    }

    /// Always returns something to show: selected items stay visible even
    /// before the catalog has loaded.
    func displayEntry(for item: Item) -> CatalogEntry {
        if let entry = entry(for: item) { return entry }
        let name = switch item {
        case .formula(let ref), .cask(let ref): ref.name
        case .mas(_, let name): name
        }
        return CatalogEntry(item: item, title: name, summary: nil, homepage: nil, installs: 0, needsAdmin: false)
    }

    /// Kit items that exist in the current catalog (kits are curated by hand
    /// and Homebrew renames things); App Store items always show.
    func entries(for kit: Kit) -> [CatalogEntry] {
        kit.items.compactMap(entry(for:))
    }

    func searchAppStore(_ term: String) async throws -> [CatalogEntry] {
        let key = term.trimmingCharacters(in: .whitespaces).lowercased()
        if let cached = appStoreQueries[key] { return cached }
        let results = try await fetch.searchAppStore(key)
        if appStoreQueries.count > 50 { appStoreQueries.removeAll() }
        appStoreQueries[key] = results
        for entry in results { appStoreEntries[entry.item] = entry }
        return results
    }

    // MARK: Selection

    func isSelected(_ item: Item) -> Bool { selectedSet.contains(item) }

    func toggle(_ item: Item) {
        if selectedSet.remove(item) != nil {
            selection.removeAll { $0 == item }
        } else {
            selectedSet.insert(item)
            selection.append(item)
        }
    }

    /// Toggles a group as one: if every item is selected, deselect them all;
    /// otherwise select the missing ones.
    func toggleAll(_ items: [Item]) {
        if items.allSatisfy(isSelected) {
            selectedSet.subtract(items)
            selection.removeAll { !selectedSet.contains($0) }
        } else {
            for item in items where selectedSet.insert(item).inserted { selection.append(item) }
        }
    }

    func clearSelection() {
        selection = []
        selectedSet = []
    }

    var installedSelectionCount: Int { selection.filter(installed.contains).count }

    // MARK: Helpers

    static func bundledKits() -> [Kit] {
        guard let url = Bundle.main.url(forResource: "kits", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let kits = try? JSONDecoder().decode([Kit].self, from: data) else {
            // Bundled and covered by tests; failing here means a broken build.
            preconditionFailure("kits.json missing or invalid in the app bundle")
        }
        return kits
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case ToolError.failed(let command, _, let stderr): stderr.isEmpty ? "\(command) failed" : stderr
        case ToolError.launchFailed(let command, let reason): "\(command): \(reason)"
        case ToolError.missing(let tool): "\(tool) is not installed"
        case FetchError.http(let url, let status): "\(url.host() ?? "Server") returned \(status)"
        default: error.localizedDescription
        }
    }
}
