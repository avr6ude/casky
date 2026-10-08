import Foundation
import Network
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
    /// Re-detected on each installed-state refresh, so installing Homebrew
    /// while casky is open is picked up when the window comes back.
    private(set) var homebrew: Homebrew?
    private let locateHomebrew: (_ userPath: String?) -> Homebrew?
    private let applicationFolders: [URL]
    private let defaults: UserDefaults

    let kits: [Kit]

    private(set) var setups: [SavedSetup] = []
    /// Set when setups.json couldn't be read; saving stays off so the file
    /// is never overwritten with an empty list.
    private(set) var setupsLoadError: String?

    private(set) var history: [RunRecord] = []
    private(set) var historyLoadError: String?

    private(set) var taps: [TapListing] = []
    /// Same contract as `setupsLoadError`, for taps.json.
    private(set) var tapsLoadError: String?

    /// A name prompt the window should show.
    enum NamePrompt {
        case newSetup(items: [Item], suggestedName: String)
        case rename(SavedSetup)
        case addTap
    }
    var namePrompt: NamePrompt?
    /// Result of the last Brewfile import, shown as a summary.
    var lastImport: Brewfile.Import?
    /// An error the user needs to see now (file read/write failures).
    var alertMessage: String?
    /// Defaults to "Something went wrong".
    var alertTitle: String?

    enum Connection: Equatable {
        case online
        case offline
        /// Just reconnected; shown for a few seconds while casky catches up.
        case backOnline
    }

    private(set) var connection = Connection.online
    /// The connection dropped while a run was going: its downloads failed
    /// for that reason, and Retry is the fix once it's back.
    var lostConnectionDuringRun = false
    private var pathMonitor: NWPathMonitor?

    /// The current or last install run; nil when none is shown.
    var run: RunState?
    var isInstalling = false
    /// Homebrew is updating its package data before a run's steps start.
    var isPreparing = false
    /// Live output of the step being installed.
    var currentOutput: [String] = []
    /// When the step in flight started, to say when it's taking long.
    var currentStepStarted: Date?

    /// "Ghostty, Slack and 2 more", for tooltips and short lists.
    func names(_ items: [Item]) -> String {
        items.map { displayEntry(for: $0).title }.formatted(.list(type: .and))
    }
    /// A non-fatal problem during the run (e.g. `brew update` failed).
    var runNote: String?
    /// What the current or last run was asked to do, for Retry.
    var lastRun: RunKind?

    /// Newer versions of what's on this Mac, by item.
    private(set) var updates: [Item: AvailableUpdate] = [:]
    private(set) var isCheckingUpdates = false
    private(set) var updatesError: String?
    /// The item shown in the Quick Look-style preview.
    var previewEntry: CatalogEntry?
    /// Whether admin prompts use Touch ID (Settings > Admin Prompts).
    var touchIDForAdmin = TouchIDForSudo.isEnabled

    private(set) var selection: [Item] = []
    private var selectedSet: Set<Item> = []

    private let fetch: CatalogFetch
    private let tapFetch: TapFetch
    private let setupsFile: JSONFile<[SavedSetup]>
    private let tapsFile: JSONFile<[TapListing]>
    private let historyFile: JSONFile<[RunRecord]>
    private let heldFile: JSONFile<[Item]>
    /// Apps a setup holds at their version. Homebrew can't pin casks, so
    /// casky remembers them and leaves them out of Update All. (Formulae
    /// are pinned in Homebrew itself.)
    private(set) var heldItems: Set<Item> = []
    /// Editor extensions and other tools on this Mac, for planning setups.
    var developerState = DeveloperState()
    /// A setup the sidebar should select, e.g. one just imported.
    var revealSetup: UUID?
    let dotfilesDirectory: URL
    let dotfilesBackupsDirectory: URL
    let preferencesBackupsDirectory: URL
    /// App Store results seen so far, so selected App Store items keep their
    /// details. Bounded by what the user searched for.
    private var appStoreEntries: [Item: CatalogEntry] = [:]
    private var appStoreQueries: [String: [CatalogEntry]] = [:]

    init(
        fetch: CatalogFetch = CatalogFetch(),
        tapFetch: TapFetch = TapFetch(),
        dataDirectory: URL = URL.applicationSupportDirectory.appending(path: "casky"),
        defaults: UserDefaults = .standard,
        locateHomebrew: @escaping (_ userPath: String?) -> Homebrew? = { Homebrew(userPath: $0) },
        applicationFolders: [URL] = InstalledApps.defaultFolders,
        kits: [Kit] = AppModel.bundledKits()
    ) {
        self.fetch = fetch
        self.tapFetch = tapFetch
        setupsFile = JSONFile(file: dataDirectory.appending(path: "setups.json"))
        tapsFile = JSONFile(file: dataDirectory.appending(path: "taps.json"))
        historyFile = JSONFile(file: dataDirectory.appending(path: "history.json"))
        heldFile = JSONFile(file: dataDirectory.appending(path: "held.json"))
        dotfilesDirectory = dataDirectory.appending(path: "dotfiles")
        dotfilesBackupsDirectory = dataDirectory.appending(path: "dotfile-backups")
        preferencesBackupsDirectory = dataDirectory.appending(path: "preference-backups")
        self.defaults = defaults
        self.locateHomebrew = locateHomebrew
        self.applicationFolders = applicationFolders
        homebrew = locateHomebrew(defaults.string(forKey: Self.homebrewPathKey))
        self.kits = kits
        do {
            setups = try setupsFile.load(empty: [])
        } catch {
            setupsLoadError = "Couldn't read your saved setups (\(setupsFile.file.path)): \(error.localizedDescription)"
        }
        do {
            history = try historyFile.load(empty: [])
        } catch {
            historyLoadError = "Couldn't read your install history (\(historyFile.file.path)): \(error.localizedDescription)"
        }
        heldItems = Set((try? heldFile.load(empty: [])) ?? [])
        do {
            taps = try tapsFile.load(empty: [])
        } catch {
            tapsLoadError = "Couldn't read your taps (\(tapsFile.file.path)): \(error.localizedDescription)"
        }
    }

    var catalog: Catalog? {
        if case .ready(let catalog) = catalogState { catalog } else { nil }
    }

    // MARK: Loading

    /// Cached catalog first for an instant launch, then a background refresh
    /// when it is missing or stale.
    func start() async {
        watchConnection()
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
        await refreshUpdates()
    }

    private func watchConnection() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in self?.setOnline(isOnline) }
        }
        monitor.start(queue: DispatchQueue(label: "casky.connection"))
        pathMonitor = monitor
    }

    /// Going offline only changes what the window says. Coming back
    /// redoes whatever failed for lack of a connection: the catalog,
    /// the update check, what's installed.
    func setOnline(_ isOnline: Bool) {
        switch (connection, isOnline) {
        case (.offline, true):
            connection = .backOnline
            Task {
                if catalog == nil || catalogRefreshError != nil { await refreshCatalog() }
                await refreshInstalled()
                await refreshUpdates()
                try? await Task.sleep(for: .seconds(5))
                if connection == .backOnline { connection = .online }
            }
        case (.online, false), (.backOnline, false):
            connection = .offline
            if isInstalling { lostConnectionDuringRun = true }
        default:
            break
        }
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

    /// Apps in the Applications folders always count; Homebrew and `mas`
    /// add what they manage when available.
    func refreshInstalled() async {
        let folders = applicationFolders
        let bundles = await Task.detached { InstalledApps.bundleNames(in: folders) }.value
        if homebrew == nil { homebrew = locateHomebrew(homebrewPathOverride) }
        guard let homebrew else {
            installed.appBundles = bundles
            return
        }
        do {
            var state = try await homebrew.installedState()
            state.appBundles = bundles
            installed = state
            installedError = nil
        } catch {
            installed.appBundles = bundles
            installedError = Self.describe(error)
        }
    }

    /// Asks Homebrew what it would upgrade (`outdated --greedy`, so apps that
    /// update themselves count too), and compares apps installed some other
    /// way with the catalog's latest version.
    func refreshUpdates() async {
        guard let homebrew, !isCheckingUpdates else { return }
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        var found: [AvailableUpdate] = []
        do {
            found = try Updates.decodeOutdated(try await homebrew.outdated(), requestedFormulae: installed.requestedFormulae)
            updatesError = nil
        } catch {
            updatesError = Self.describe(error)
        }
        if let catalog {
            let installed = installed
            found += await Task.detached { LocalApp.unmanagedUpdates(in: catalog.entries, installed: installed) }.value
        }
        for index in found.indices where heldItems.contains(found[index].item) { found[index].isHeld = true }
        updates = Dictionary(found.map { ($0.item, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func setHeld(_ item: Item, _ isHeld: Bool) {
        if isHeld { heldItems.insert(item) } else { heldItems.remove(item) }
        updates[item]?.isHeld = isHeld
        do {
            try heldFile.save(heldItems.sorted { $0.technicalName < $1.technicalName })
        } catch {
            alertMessage = "Couldn't save held apps: \(error.localizedDescription)"
        }
    }

    func isInstalled(_ item: Item) -> Bool {
        let entry = entry(for: item)
        return installed.isPresent(item, appBundle: entry?.appBundleName, conflicts: entry?.conflicts ?? [])
    }

    /// Whether Homebrew or `mas` manages it, as opposed to an app that was
    /// installed some other way.
    func isManaged(_ item: Item) -> Bool { installed.contains(item) }

    // MARK: Entries

    func entry(for item: Item) -> CatalogEntry? {
        if case .mas(let id, let name) = item {
            return appStoreEntries[item]
                ?? CatalogEntry(item: item, title: name, summary: nil, homepage: URL(string: "https://apps.apple.com/app/id\(id)"),
                                installs: 0, needsAdmin: false, appBundleName: "\(name).app")
        }
        if let entry = catalog?.entry(for: item) { return entry }
        // Items from an added tap aren't in the Homebrew catalog.
        switch item {
        case .formula(let ref), .cask(let ref):
            guard let name = ref.tap, let tap = taps.first(where: { $0.name == name }) else { return nil }
            return CatalogEntry(item: item, title: ref.name, summary: "From \(tap.name)", homepage: tap.repositoryURL, installs: 0, needsAdmin: false)
        case .mas:
            return nil
        }
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

    private var topAppStoreApps: [CatalogEntry]?

    /// Fetched once per launch.
    func topAppStore() async throws -> [CatalogEntry] {
        if let topAppStoreApps { return topAppStoreApps }
        let apps = try await fetch.topAppStoreApps()
        for entry in apps { appStoreEntries[entry.item] = entry }
        topAppStoreApps = apps
        return apps
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

    var installedSelectionCount: Int { selection.filter(isInstalled).count }

    // MARK: Setups

    func promptToSaveSelection() {
        namePrompt = .newSetup(items: selection, suggestedName: "My setup")
    }

    /// Snapshot of what's installed on purpose, offered as a new setup.
    func promptToSaveThisMac() async {
        guard homebrew != nil else {
            alertMessage = "casky needs Homebrew to see what's installed on this Mac."
            return
        }
        await refreshInstalled()
        if let installedError {
            alertMessage = installedError
            return
        }
        let name = Host.current().localizedName ?? "This Mac"
        namePrompt = .newSetup(items: installed.snapshot(), suggestedName: name)
    }

    func saveSetup(named name: String, items: [Item]) {
        let setup = SavedSetup(id: UUID(), name: Self.cleanName(name, fallback: "My setup"), items: items, createdAt: .now)
        setups.insert(setup, at: 0)
        persistSetups()
    }

    func renameSetup(_ id: SavedSetup.ID, to name: String) {
        guard let index = setups.firstIndex(where: { $0.id == id }) else { return }
        setups[index].name = Self.cleanName(name, fallback: setups[index].name)
        persistSetups()
    }

    func addSetup(_ setup: SavedSetup) {
        setups.insert(setup, at: 0)
        persistSetups()
    }

    /// Changes a saved setup in place and saves it.
    func updateSetup(_ id: SavedSetup.ID, _ change: (inout SavedSetup) -> Void) {
        guard let index = setups.firstIndex(where: { $0.id == id }) else { return }
        change(&setups[index])
        persistSetups()
    }

    func setRule(_ rule: PackagePolicy.Rule?, for item: Item, in id: SavedSetup.ID) {
        guard let index = setups.firstIndex(where: { $0.id == id }) else { return }
        setups[index].setRule(rule, for: item)
        persistSetups()
    }

    func replace(_ item: Item, with replacement: Item, in id: SavedSetup.ID) {
        guard let index = setups.firstIndex(where: { $0.id == id }) else { return }
        setups[index].replace(item, with: replacement)
        persistSetups()
    }

    func deleteSetup(_ id: SavedSetup.ID) {
        setups.removeAll { $0.id == id }
        persistSetups()
    }

    func saveDotfiles(_ configuration: DotfilesConfiguration?, for id: SavedSetup.ID) throws {
        if let setupsLoadError { throw DotfilesError.invalid(setupsLoadError) }
        guard let index = setups.firstIndex(where: { $0.id == id }) else {
            throw DotfilesError.invalid("This setup no longer exists.")
        }
        var updated = setups
        updated[index].dotfiles = try configuration?.validated()
        try setupsFile.save(updated)
        setups = updated
    }

    func saveMacPreferences(_ preferences: [MacPreference], for id: SavedSetup.ID) throws {
        if let setupsLoadError { throw MacPreferencesError.invalid(setupsLoadError) }
        guard let index = setups.firstIndex(where: { $0.id == id }) else {
            throw MacPreferencesError.invalid("This setup no longer exists.")
        }
        var updated = setups
        updated[index].macPreferences = try MacPreference.validated(preferences)
        try setupsFile.save(updated)
        setups = updated
    }

    private func persistSetups() {
        guard setupsLoadError == nil else { return }
        do {
            try setupsFile.save(setups)
        } catch {
            alertMessage = "Couldn't save your setups: \(error.localizedDescription)"
        }
    }

    private static func cleanName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    // MARK: History

    func record(_ run: RunState) {
        guard !run.plan.steps.isEmpty else { return }
        let record = RunRecord(run: run, date: .now, title: { title(for: $0) }, itemTitle: { displayEntry(for: $0).title })
        history = RunRecord.appending(record, to: history)
        guard historyLoadError == nil else { return }
        do {
            try historyFile.save(history)
        } catch {
            alertMessage = "Couldn't save the install history: \(error.localizedDescription)"
        }
    }

    // MARK: Taps

    /// Fetches the tap's contents from GitHub and keeps it in the sidebar.
    /// Adding again refreshes the listing.
    func addTap(_ raw: String) async {
        do {
            let name = try Ref.parseTap(raw)
            let listing = try await tapFetch.fetch(name)
            if let index = taps.firstIndex(where: { $0.name == name }) {
                taps[index] = listing
            } else {
                taps.append(listing)
            }
            persistTaps()
        } catch {
            alertMessage = Self.describe(error)
        }
    }

    func removeTap(_ name: String) {
        taps.removeAll { $0.name == name }
        persistTaps()
    }

    private func persistTaps() {
        guard tapsLoadError == nil else { return }
        do {
            try tapsFile.save(taps)
        } catch {
            alertMessage = "Couldn't save your taps: \(error.localizedDescription)"
        }
    }

    // MARK: Brewfiles

    /// Adds the file's plain entries to the selection and keeps a summary of
    /// what was skipped. The file is read, never executed.
    func importBrewfile(at url: URL) {
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            alertMessage = "Couldn't read \(url.lastPathComponent): \(error.localizedDescription)"
            return
        }
        let result = Brewfile.read(text)
        for item in result.items where !isSelected(item) { toggle(item) }
        lastImport = result
    }

    func brewfile(for items: [Item]) -> String { Brewfile.render(items) }

    // MARK: Homebrew location

    static let homebrewPathKey = "homebrewPath"

    /// The `brew` the user picked in Settings, if any.
    var homebrewPathOverride: String? { defaults.string(forKey: Self.homebrewPathKey) }

    /// Uses the `brew` at `url` after checking it really is Homebrew, or goes
    /// back to the standard locations when `url` is nil.
    func setHomebrewPath(_ url: URL?) async throws {
        if let url {
            let candidate = Homebrew(executable: url)
            let version = String(decoding: try await candidate.run(["--version"]), as: UTF8.self)
            guard version.hasPrefix("Homebrew") else { throw SettingsError.notHomebrew(url.path) }
            defaults.set(url.path, forKey: Self.homebrewPathKey)
            homebrew = candidate
        } else {
            defaults.removeObject(forKey: Self.homebrewPathKey)
            homebrew = locateHomebrew(nil)
        }
        await refreshInstalled()
    }

    enum SettingsError: Error, Equatable {
        case notHomebrew(String)
    }

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
        case RefError.invalid(let raw): "\"\(raw)\" isn't a valid name. Taps look like owner/repo."
        case TapError.notFound(let tap): "\(tap) has no Formula or Casks folder on GitHub. Check the name, or that it's a public repository."
        case TapError.rateLimited: "GitHub's limit for anonymous requests was reached. Try again in an hour."
        case SettingsError.notHomebrew(let path): "\(path) doesn't look like Homebrew's brew command."
        case FetchError.noInstallerPackage: "The latest Homebrew release has no installer package."
        default: error.localizedDescription
        }
    }
}
