import SwiftUI

/// First screen: what casky does, and the kits as the quickest way in.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    let open: (Kit) -> Void

    var body: some View {
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
        .navigationTitle("Start")
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
        let entries = model.entries(for: kit)
        let items = entries.map(\.item)
        CatalogGate {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: kit.symbol)
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kit.title).font(.title.bold())
                        Text(kit.summary).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(items.allSatisfy(model.isSelected) ? "Deselect All" : "Select All") {
                        model.toggleAll(items)
                    }
                    .controlSize(.large)
                    .disabled(items.isEmpty)
                }
                .padding(24)
                Divider()
                ItemList(entries: entries)
            }
        }
        .navigationTitle(kit.title)
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
    @Environment(AppModel.self) private var model
    let kind: Item.Kind
    @State private var query = ""
    @State private var results: [CatalogEntry] = []
    @State private var searchError: String?
    @State private var isSearching = false

    var body: some View {
        Group {
            if kind == .mas {
                appStore
            } else {
                CatalogGate { homebrew }
            }
        }
        .navigationTitle(kind.pluralLabel)
        .searchable(text: $query, placement: .toolbar, prompt: "Search \(kind.pluralLabel)")
        .task(id: SearchKey(query: query, catalogVersion: model.catalogVersion)) { await search() }
    }

    @ViewBuilder private var homebrew: some View {
        if results.isEmpty, !query.isEmpty, !isSearching {
            ContentUnavailableView.search(text: query)
        } else {
            ItemList(entries: results)
        }
    }

    @ViewBuilder private var appStore: some View {
        if let searchError {
            ContentUnavailableView {
                Label("Couldn't search the App Store", systemImage: "wifi.exclamationmark")
            } description: {
                Text(searchError)
            } actions: {
                Button("Try Again") { Task { await search() } }
            }
        } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView(
                "Search the App Store",
                systemImage: kind.symbol,
                description: Text("casky can install App Store apps you've already got with your Apple Account.")
            )
        } else if results.isEmpty, !isSearching {
            ContentUnavailableView.search(text: query)
        } else {
            ItemList(entries: results)
        }
    }

    private struct SearchKey: Equatable {
        let query: String
        let catalogVersion: Int
    }

    private func search() async {
        isSearching = true
        defer { isSearching = false }
        if kind == .mas {
            let term = query.trimmingCharacters(in: .whitespaces)
            guard !term.isEmpty else { results = []; searchError = nil; return }
            // Wait for typing to pause before hitting the network.
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            do {
                results = try await model.searchAppStore(term)
                searchError = nil
            } catch is CancellationError {
            } catch {
                searchError = AppModel.describe(error)
            }
        } else if let catalog = model.catalog {
            let query = query, kind = kind
            let found = await Task.detached { catalog.search(query, kind: kind) }.value
            if !Task.isCancelled { results = found }
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

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("^[\(model.selection.count) item](inflect: true) selected")
                    .font(.headline)
                if model.installedSelectionCount > 0 {
                    Text("\(model.installedSelectionCount) already installed")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Clear", role: .destructive) { model.clearSelection() }
            Button("Review", action: review)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
