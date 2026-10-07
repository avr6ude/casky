import SwiftUI

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
    private enum Content: String, CaseIterable { case packages = "Apps & Tools", dotfiles = "Dotfiles", preferences = "Mac Preferences" }
    @State private var content = Content.packages
    @State private var isApplying = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Setup content", selection: $content) {
                ForEach(Content.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 440)
            .padding(.top, 16)
            switch content {
            case .packages: packages
            case .dotfiles: DotfilesView(setup: setup).id(setup.id)
            case .preferences: MacPreferencesView(setup: setup).id(setup.id)
            }
        }
        .navigationTitle(setup.name)
        .sheet(isPresented: $isApplying) { ApplySetupSheet(setup: setup) }
        .toolbar {
            Button("Apply Setup…", systemImage: "play.fill") { isApplying = true }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.borderedProminent)
                .disabled(model.isInstalling)
                .help("Install this setup's apps and tools, restore its dotfiles and apply its Mac preferences")
            Menu {
                Button("Rename…") { model.namePrompt = .rename(setup) }
                Divider()
                Button("Export Brewfile…") { model.exportBrewfile(setup.items) }
                Button("Export Ansible Playbook…") { model.exportAnsible(setup) }
                Divider()
                Button("Delete Setup", role: .destructive) { model.deleteSetup(setup.id) }
            } label: {
                Label("Setup", systemImage: "ellipsis.circle")
            }
            .help("Rename, export or delete this setup")
        }
    }

    private var packages: some View {
        CollectionView(
            symbol: "square.stack",
            title: setup.name,
            subtitle: "Saved \(setup.createdAt.formatted(date: .abbreviated, time: .omitted))",
            entries: setup.items.map(model.displayEntry(for:))
        )
    }
}

/// The one check before applying a setup: everything that will happen, in
/// the order it runs.
private struct ApplySetupSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let setup: SavedSetup

    var body: some View {
        let plan = model.previewPlan(for: setup)
        let taps = plan.steps.compactMap { if case .tap(let tap) = $0.action { tap } else { nil } }
        let installs = plan.steps.compactMap { if case .install(let item) = $0.action { item } else { nil } }
        let dotfiles = setup.dotfiles?.files ?? []
        let preferences = setup.macPreferences ?? []
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apply \(setup.name)?").font(.title2.bold())
                Text("Runs top to bottom. You can stop after any step and retry what didn't finish.")
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 24)
            Form {
                Section("Apps & Tools") {
                    ForEach(taps, id: \.self) { tap in
                        LabeledContent("Add tap \(tap)", value: "Tap")
                    }
                    ForEach(installs, id: \.self) { item in
                        let entry = model.displayEntry(for: item)
                        LabeledContent {
                            Text(item.kind.label)
                        } label: {
                            Label { Text(entry.title) } icon: { ItemIcon(entry: entry, size: 20) }
                        }
                    }
                    if !plan.alreadyInstalled.isEmpty || installs.isEmpty {
                        Text(setup.items.isEmpty ? "None in this setup" : "^[\(plan.alreadyInstalled.count) already installed](inflect: true), skipped")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Dotfiles") {
                    if dotfiles.isEmpty {
                        Text("None in this setup").foregroundStyle(.secondary)
                    } else {
                        ForEach(dotfiles) { file in
                            LabeledContent("~/\(file.destination.value)", value: file.mode.title)
                        }
                    }
                }
                Section("Mac Preferences") {
                    if preferences.isEmpty {
                        Text("None in this setup").foregroundStyle(.secondary)
                    } else {
                        ForEach(preferences) { preference in
                            LabeledContent(preference.title, value: preference.describe(preference.value))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            HStack(spacing: 12) {
                Text(note(installs: installs))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Apply Setup") {
                    dismiss()
                    Task { await model.apply(setup) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(plan.steps.isEmpty || model.isInstalling)
            }
            .controlSize(.large)
            .padding(20)
        }
        .frame(width: 560, height: 600)
    }

    private func note(installs: [Item]) -> String {
        if model.homebrew == nil, !installs.isEmpty { return "Homebrew isn't installed, so apps and tools will be skipped." }
        var notes: [String] = []
        if installs.contains(where: { $0.kind == .mas }) { notes.append("App Store apps need you signed in to the App Store.") }
        if installs.contains(where: { model.catalog?.entry(for: $0)?.needsAdmin == true }) { notes.append("Some installs ask for Touch ID or your password.") }
        if setup.dotfiles?.files.isEmpty == false || setup.macPreferences?.isEmpty == false { notes.append("Originals are backed up first.") }
        return notes.joined(separator: " ")
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
                Button(!items.isEmpty && items.allSatisfy(model.isSelected) ? "Deselect All" : "Select All") {
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
    let kind: Item.Kind?
    @State private var query = ""

    var body: some View {
        let title = kind?.pluralLabel ?? "All Apps"
        SearchResults(query: query, kind: kind)
            .navigationTitle(title)
            .searchable(text: $query, placement: .toolbar, prompt: kind == nil ? "Search apps, tools and the App Store" : "Search \(title)")
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
        if kind == .mas, term.isEmpty, appStoreResults.isEmpty, appStoreError == nil {
            ProgressView("Loading top apps…").frame(maxWidth: .infinity, maxHeight: .infinity)
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
                if kind == .mas, term.isEmpty {
                    Text("Top free Mac apps today")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    Divider()
                }
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
            // Searching everything with no query lists Homebrew's catalog;
            // the App Store section opens on today's chart instead.
            if kind == .mas {
                do {
                    appStoreResults = try await model.topAppStore()
                    appStoreError = nil
                } catch is CancellationError {
                } catch {
                    appStoreError = AppModel.describe(error)
                }
            } else {
                appStoreResults = []
                appStoreError = nil
            }
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
