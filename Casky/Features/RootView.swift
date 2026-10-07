import AppKit
import SwiftUI

enum Destination: Hashable {
    case home
    case selection
    case history
    case browse(Item.Kind)
    case kit(String)
    case setup(UUID)
    case tap(String)
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var destination: Destination? = .home

    var body: some View {
        NavigationSplitView {
            Sidebar(destination: $destination)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            detail
                // Fill the column so the bar sits at the window's bottom even
                // when the content (an empty state) is short.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !model.selection.isEmpty {
                        SelectionBar { destination = .selection }
                    }
                }
        }
        .task { await model.start() }
        .modifier(Prompts())
        .sheet(isPresented: Binding(get: { model.run != nil }, set: { if !$0 { model.dismissRun() } })) {
            if let run = model.run { RunView(run: run) }
        }
        .sheet(item: Bindable(model).previewEntry) { entry in
            AppPreview(entry: entry)
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.importBrewfile(at: url)
            destination = .selection
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refreshInstalled() }
        }
    }

    @ViewBuilder private var detail: some View {
        switch destination ?? .home {
        case .home:
            HomeView { destination = .kit($0.slug) }
        case .selection:
            SelectionView()
        case .history:
            HistoryView()
        case .browse(let kind):
            BrowseView(kind: kind).id(kind)
        case .kit(let slug):
            if let kit = model.kits.first(where: { $0.slug == slug }) {
                KitView(kit: kit).id(slug)
            }
        case .setup(let id):
            if let setup = model.setups.first(where: { $0.id == id }) {
                SetupView(setup: setup).id(id)
            } else {
                ContentUnavailableView("This setup was deleted", systemImage: "square.stack")
            }
        case .tap(let name):
            if let tap = model.taps.first(where: { $0.name == name }) {
                TapView(tap: tap).id(name)
            } else {
                ContentUnavailableView("This tap was removed", systemImage: "shippingbox")
            }
        }
    }
}

private struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Binding var destination: Destination?

    var body: some View {
        List(selection: $destination) {
            Label("Start", systemImage: "sparkles.rectangle.stack").tag(Destination.home)
            Label("Selected", systemImage: "checklist")
                .badge(model.selection.count)
                .tag(Destination.selection)
            Label("History", systemImage: "clock.arrow.circlepath").tag(Destination.history)

            Section("Browse") {
                ForEach([Item.Kind.cask, .formula, .mas], id: \.self) { kind in
                    Label(kind.pluralLabel, systemImage: kind.symbol).tag(Destination.browse(kind))
                }
            }

            Section("My Setups") {
                ForEach(model.setups) { setup in
                    Label(setup.name, systemImage: "square.stack")
                        .tag(Destination.setup(setup.id))
                        .contextMenu {
                            Button("Rename…") { model.namePrompt = .rename(setup) }
                            Button("Export Brewfile…") { model.exportBrewfile(setup.items) }
                            Divider()
                            Button("Delete Setup", role: .destructive) { model.deleteSetup(setup.id) }
                        }
                }
                Button {
                    Task { await model.promptToSaveThisMac() }
                } label: {
                    Label("Save This Mac…", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Section("Taps") {
                ForEach(model.taps) { tap in
                    Label(tap.name, systemImage: "shippingbox")
                        .tag(Destination.tap(tap.name))
                        .contextMenu {
                            Button("Refresh") { Task { await model.addTap(tap.name) } }
                            Divider()
                            Button("Remove Tap", role: .destructive) { model.removeTap(tap.name) }
                        }
                }
                Button {
                    model.namePrompt = .addTap
                } label: {
                    Label("Add Tap…", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Section("Kits") {
                ForEach(model.kits) { kit in
                    Label(kit.title, systemImage: kit.symbol).tag(Destination.kit(kit.slug))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { StatusFooter() }
    }
}

/// Background problems that don't block the window: a failed catalog refresh
/// with a usable cached copy, or Homebrew not being found.
private struct StatusFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.isRefreshingCatalog, model.catalog != nil {
                Label("Updating catalog…", systemImage: "arrow.triangle.2.circlepath")
            }
            if let error = model.catalogRefreshError {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Couldn't update the catalog. Using the saved copy.")
                        Button("Try again") { Task { await model.refreshCatalog() } }
                            .buttonStyle(.link)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .help(error)
            }
            if let error = model.historyLoadError {
                Label("Install history couldn't be read. casky won't change the file.", systemImage: "exclamationmark.triangle")
                    .help(error)
            }
            if let error = model.tapsLoadError {
                Label("Taps couldn't be read. casky won't change the file.", systemImage: "exclamationmark.triangle")
                    .help(error)
            }
            if let error = model.setupsLoadError {
                Label("Saved setups couldn't be read. casky won't change the file.", systemImage: "exclamationmark.triangle")
                    .help(error)
            }
            if model.homebrew == nil {
                Label("Homebrew not found. casky needs it to install.", systemImage: "exclamationmark.triangle")
            } else if let error = model.installedError {
                Label("Couldn't check what's installed.", systemImage: "exclamationmark.triangle")
                    .help(error)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}

/// Name prompts, the Brewfile import summary and error alerts.
private struct Prompts: ViewModifier {
    @Environment(AppModel.self) private var model
    @State private var name = ""

    func body(content: Content) -> some View {
        @Bindable var model = model
        content
            .alert(promptTitle, isPresented: isPresented($model.namePrompt), presenting: model.namePrompt) { prompt in
                if case .addTap = prompt {
                    TextField("owner/repo", text: $name)
                } else {
                    TextField("Name", text: $name)
                }
                Button(prompt.isAddTap ? "Add" : "Save") {
                    switch prompt {
                    case .newSetup(let items, _): model.saveSetup(named: name, items: items)
                    case .rename(let setup): model.renameSetup(setup.id, to: name)
                    case .addTap:
                        let tap = name
                        Task { await model.addTap(tap) }
                    }
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) {}
            } message: { prompt in
                switch prompt {
                case .newSetup(let items, _):
                    Text("^[\(items.count) item](inflect: true) will be saved on this Mac.")
                case .addTap:
                    Text("casky lists the tap's apps and tools from GitHub. Installing one adds the tap to Homebrew.")
                case .rename:
                    EmptyView()
                }
            }
            .onChange(of: model.namePrompt == nil) {
                // Seed the field each time a prompt opens.
                switch model.namePrompt {
                case .newSetup(_, let suggestedName): name = suggestedName
                case .rename(let setup): name = setup.name
                case .addTap: name = ""
                case nil: break
                }
            }
            .alert("Brewfile imported", isPresented: isPresented($model.lastImport), presenting: model.lastImport) { _ in
                Button("OK") {}
            } message: { result in
                Text(importSummary(result))
            }
            .alert("Something went wrong", isPresented: isPresented($model.alertMessage), presenting: model.alertMessage) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
    }

    private var promptTitle: String {
        switch model.namePrompt {
        case .rename: "Rename Setup"
        case .addTap: "Add Tap"
        default: "Save Setup"
        }
    }

    private func isPresented<Value>(_ binding: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue != nil }, set: { if !$0 { binding.wrappedValue = nil } })
    }

    private func importSummary(_ result: Brewfile.Import) -> String {
        let count = result.items.count
        var lines = ["Added \(count) \(count == 1 ? "item" : "items") to your selection."]
        if result.optionsIgnored > 0 {
            lines.append("Options on \(result.optionsIgnored) lines were ignored.")
        }
        if !result.skipped.isEmpty {
            lines.append("Skipped \(result.skipped.count) lines casky can't read safely:")
            lines.append(contentsOf: result.skipped.prefix(8))
            if result.skipped.count > 8 { lines.append("…and \(result.skipped.count - 8) more") }
        }
        return lines.joined(separator: "\n")
    }
}

private extension AppModel.NamePrompt {
    var isAddTap: Bool { if case .addTap = self { true } else { false } }
}
