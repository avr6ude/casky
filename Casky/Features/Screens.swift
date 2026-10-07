import SwiftUI

/// First screen: what casky does, and the kits as the quickest way in.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    let open: (Kit) -> Void
    @State private var query = ""

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                kits
            } else {
                SearchResults(query: query, kind: nil)
            }
        }
        .navigationTitle("Start")
        .searchable(text: $query, placement: .toolbar, prompt: "Search apps, tools and the App Store")
    }

    private var kits: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set up this Mac")
                        .font(.largeTitle.bold())
                    Text("Pick a kit or search. casky installs everything with Homebrew and the App Store.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(model.kits) { kit in
                        KitCard(kit: kit, count: model.catalog == nil ? kit.items.count : model.entries(for: kit).count) {
                            open(kit)
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 1100, alignment: .leading)
        }
    }
}

private struct KitCard: View {
    let kit: Kit
    let count: Int
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: kit.symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(height: 28)
                Text(kit.title)
                    .font(.headline)
                Text(kit.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                Text("^[\(count) item](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary.opacity(isHovered ? 2 : 1), in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityHint("Opens the kit")
    }
}

struct KitView: View {
    @Environment(AppModel.self) private var model
    let kit: Kit

    var body: some View {
        CatalogGate {
            CollectionView(symbol: kit.symbol, title: kit.title, subtitle: kit.summary, entries: model.entries(for: kit))
        }
        .navigationTitle(kit.title)
    }
}

struct SetupView: View {
    @Environment(AppModel.self) private var model
    let setup: SavedSetup

    var body: some View {
        CollectionView(
            symbol: "square.stack",
            title: setup.name,
            subtitle: "Saved \(setup.createdAt.formatted(date: .abbreviated, time: .omitted))",
            entries: setup.items.map(model.displayEntry(for:))
        ) {
            Menu {
                Button("Rename…") { model.namePrompt = .rename(setup) }
                Button("Export Brewfile…") { model.exportBrewfile(setup.items) }
                Divider()
                Button("Delete Setup", role: .destructive) { model.deleteSetup(setup.id) }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .navigationTitle(setup.name)
    }
}

struct TapView: View {
    @Environment(AppModel.self) private var model
    let tap: TapListing

    var body: some View {
        CollectionView(
            symbol: "shippingbox",
            title: tap.name,
            subtitle: "\(tap.formulae.count) command-line tools, \(tap.casks.count) apps · \(tap.repositoryURL.host() ?? "")\(tap.repositoryURL.path())",
            entries: tap.items.map(model.displayEntry(for:))
        ) {
            Button("Refresh") { Task { await model.addTap(tap.name) } }
        }
        .navigationTitle(tap.name)
    }
}

/// Header with a Select All toggle above a list of entries; shared by kits
/// and saved setups.
struct CollectionView<Actions: View>: View {
    @Environment(AppModel.self) private var model
    let symbol: String
    let title: String
    let subtitle: String
    let entries: [CatalogEntry]
    @ViewBuilder var actions: Actions

    var body: some View {
        let items = entries.map(\.item)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: symbol)
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title.bold())
                    Text(subtitle).foregroundStyle(.secondary)
                }
                Spacer()
                actions
                Button(items.allSatisfy(model.isSelected) ? "Deselect All" : "Select All") {
                    model.toggleAll(items)
                }
                .disabled(items.isEmpty)
                let missing = items.filter { !model.isInstalled($0) }
                Button(missing.isEmpty && !items.isEmpty ? "All Installed" : "Install Now") {
                    Task { await model.install(missing) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(missing.isEmpty || model.isInstalling || model.homebrew == nil)
                .help(missing.isEmpty ? "Everything here is already installed" : "Install the \(missing.count) not installed yet")
            }
            .controlSize(.large)
            .padding(24)
            Divider()
            ItemList(entries: entries)
        }
    }
}

extension CollectionView where Actions == EmptyView {
    init(symbol: String, title: String, subtitle: String, entries: [CatalogEntry]) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, entries: entries) { EmptyView() }
    }
}

struct SelectionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.selection.isEmpty {
                ContentUnavailableView(
                    "Nothing selected yet",
                    systemImage: "checklist",
                    description: Text("Pick apps and tools from a kit or search to build your setup.")
                )
            } else {
                ItemList(entries: model.selection.map(model.displayEntry(for:)))
            }
        }
        .navigationTitle("Selected")
    }
}

struct BrowseView: View {
    let kind: Item.Kind
    @State private var query = ""

    var body: some View {
        SearchResults(query: query, kind: kind)
            .navigationTitle(kind.pluralLabel)
            .searchable(text: $query, placement: .toolbar, prompt: "Search \(kind.pluralLabel)")
    }
}

/// Search over one source, or over everything (Homebrew first, then the
/// App Store) when `kind` is nil.
struct SearchResults: View {
    @Environment(AppModel.self) private var model
    let query: String
    let kind: Item.Kind?
    /// Every Homebrew match, ranked; the list shows `visibleCount` of them
    /// and grows as you scroll.
    @State private var homebrewResults: [CatalogEntry] = []
    @State private var visibleCount = Self.pageSize
    @State private var appStoreResults: [CatalogEntry] = []
    @State private var appStoreError: String?
    @State private var isSearching = false

    private var includesHomebrew: Bool { kind != .mas }
    private var includesAppStore: Bool { kind == nil || kind == .mas }
    private var term: String { query.trimmingCharacters(in: .whitespaces) }
    private static let pageSize = 100
    private var results: [CatalogEntry] { Array(homebrewResults.prefix(visibleCount)) + appStoreResults }

    var body: some View {
        Group {
            if includesHomebrew {
                CatalogGate { content }
            } else {
                content
            }
        }
        .task(id: SearchKey(query: query, catalogVersion: model.catalogVersion)) { await search() }
    }

    @ViewBuilder private var content: some View {
        if kind == .mas, term.isEmpty {
            ContentUnavailableView(
                "Search the App Store",
                systemImage: Item.Kind.mas.symbol,
                description: Text("casky installs free App Store apps and apps you've already bought with your Apple Account.")
            )
        } else if let appStoreError, results.isEmpty, !isSearching {
            ContentUnavailableView {
                Label("Couldn't search the App Store", systemImage: "wifi.exclamationmark")
            } description: {
                Text(appStoreError)
            } actions: {
                Button("Try Again") { Task { await search() } }
            }
        } else if results.isEmpty, !term.isEmpty, !isSearching {
            ContentUnavailableView.search(text: query)
        } else {
            VStack(spacing: 0) {
                if let appStoreError {
                    Label("App Store results are missing: \(appStoreError)", systemImage: "wifi.exclamationmark")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    Divider()
                }
                ItemList(entries: results) {
                    if visibleCount < homebrewResults.count { visibleCount += Self.pageSize }
                }
            }
        }
    }

    private struct SearchKey: Equatable {
        let query: String
        let catalogVersion: Int
    }

    private func search() async {
        isSearching = true
        defer { isSearching = false }
        if includesHomebrew, let catalog = model.catalog {
            let query = query, kind = kind
            let found = await Task.detached { catalog.search(query, kind: kind, limit: nil) }.value
            guard !Task.isCancelled else { return }
            homebrewResults = found
            visibleCount = Self.pageSize
        }
        guard includesAppStore else { return }
        guard !term.isEmpty else {
            appStoreResults = []
            appStoreError = nil
            return
        }
        // Wait for typing to pause before hitting the network.
        do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
        do {
            appStoreResults = try await model.searchAppStore(term)
            appStoreError = nil
        } catch is CancellationError {
        } catch {
            appStoreResults = []
            appStoreError = AppModel.describe(error)
        }
    }
}

/// Shows its content once the Homebrew catalog is available, and a loading
/// or error state before that.
struct CatalogGate<Content: View>: View {
    @Environment(AppModel.self) private var model
    @ViewBuilder let content: Content

    var body: some View {
        switch model.catalogState {
        case .ready:
            content
        case .loading:
            ProgressView("Loading the Homebrew catalog…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load the Homebrew catalog", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await model.refreshCatalog() } }
                    .disabled(model.isRefreshingCatalog)
            }
        }
    }
}

struct SelectionBar: View {
    @Environment(AppModel.self) private var model
    let review: () -> Void
    @State private var isConfirming = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: review) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("^[\(model.selection.count) item](inflect: true) selected")
                        .font(.headline)
                    if model.installedSelectionCount > 0 {
                        Text("\(model.installedSelectionCount) already installed")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Review the selection")
            Spacer()
            Button("Clear", role: .destructive) { model.clearSelection() }
            Menu("Save") {
                Button("Save as Setup…") { model.promptToSaveSelection() }
                Button("Export Brewfile…") { model.exportBrewfile(model.selection) }
            }
            .fixedSize()
            Button("Install…") { isConfirming = true }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isInstalling)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .modifier(InstallConfirmation(isPresented: $isConfirming))
    }
}

/// The check before anything runs: what will be installed, what's skipped,
/// what will ask for a password. Without Homebrew, offers to get it.
private struct InstallConfirmation: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        let plan = model.previewPlan()
        let installs = plan.steps.compactMap { if case .install(let item) = $0.action { item } else { nil } }
        let needsPassword = installs.filter { if case .mas = $0 { true } else { model.catalog?.entry(for: $0)?.needsAdmin == true } }
        content
            .alert("casky needs Homebrew", isPresented: presented(when: model.homebrew == nil)) {
                Button("Download Homebrew Installer") {
                    isPresented = false
                    Task { await model.installHomebrew() }
                }
                Button("Cancel", role: .cancel) { isPresented = false }
            } message: {
                Text("Homebrew installs the apps and tools. casky will download Homebrew's official installer from GitHub and open it. Come back here when it's done.")
            }
            .confirmationDialog(
                installs.isEmpty ? "Everything selected is already installed" : "Install \(installs.count) \(installs.count == 1 ? "item" : "items")?",
                isPresented: presented(when: model.homebrew != nil)
            ) {
                if !installs.isEmpty {
                    Button("Install") {
                        isPresented = false
                        Task { await model.install() }
                    }
                }
                Button("Cancel", role: .cancel) { isPresented = false }
            } message: {
                Text(summary(plan: plan, needsPassword: needsPassword.count, hasAppStore: installs.contains { $0.kind == .mas }))
            }
    }

    private func presented(when condition: Bool) -> Binding<Bool> {
        Binding(get: { isPresented && condition }, set: { if !$0 { isPresented = false } })
    }

    private func summary(plan: InstallPlan, needsPassword: Int, hasAppStore: Bool) -> String {
        var lines = ["Homebrew and the App Store will install these on this Mac."]
        if !plan.alreadyInstalled.isEmpty { lines.append("\(plan.alreadyInstalled.count) already installed will be skipped.") }
        if needsPassword > 0 { lines.append("\(needsPassword) need admin rights (Touch ID or your Mac password).") }
        if hasAppStore { lines.append("App Store apps need you to be signed in to the App Store.") }
        return lines.joined(separator: "\n")
    }
}
