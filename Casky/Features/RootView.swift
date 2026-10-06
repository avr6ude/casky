import AppKit
import SwiftUI

enum Destination: Hashable {
    case home
    case selection
    case browse(Item.Kind)
    case kit(String)
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
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !model.selection.isEmpty {
                        SelectionBar { destination = .selection }
                    }
                }
        }
        .task { await model.start() }
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
        case .browse(let kind):
            BrowseView(kind: kind).id(kind)
        case .kit(let slug):
            if let kit = model.kits.first(where: { $0.slug == slug }) {
                KitView(kit: kit).id(slug)
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

            Section("Browse") {
                ForEach([Item.Kind.cask, .formula, .mas], id: \.self) { kind in
                    Label(kind.pluralLabel, systemImage: kind.symbol).tag(Destination.browse(kind))
                }
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
