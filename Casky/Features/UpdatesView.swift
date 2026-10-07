import SwiftUI

/// Everything on this Mac with a newer version: Homebrew's own list plus
/// apps installed some other way.
struct UpdatesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let entries = model.updates.keys.map(model.displayEntry(for:)).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "arrow.down.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Updates").font(.title.bold())
                    Text(subtitle(count: entries.count)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check Again") { Task { await model.refreshUpdates() } }
                    .disabled(model.isCheckingUpdates)
                let chosen = entries.map(\.item).filter(model.isSelected)
                if !chosen.isEmpty {
                    Button("Update \(chosen.count) Selected") { Task { await model.update(chosen) } }
                        .disabled(model.isInstalling)
                }
                Button("Update All") { Task { await model.update(entries.map(\.item)) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(entries.isEmpty || model.isInstalling)
            }
            .controlSize(.large)
            .padding(24)
            Divider()
            if entries.isEmpty {
                ContentUnavailableView {
                    Label(model.isCheckingUpdates ? "Checking for updates…" : "Everything is up to date", systemImage: "checkmark.circle")
                } description: {
                    if let error = model.updatesError { Text(error) }
                }
            } else {
                ItemList(entries: entries, showsUpdateVersions: true)
            }
        }
        .navigationTitle("Updates")
    }

    private func subtitle(count: Int) -> String {
        if model.isCheckingUpdates { return "Checking…" }
        switch count {
        case 0: return "Apps and tools on this Mac are current."
        case 1: return "1 app or tool has a newer version."
        default: return "\(count) apps and tools have newer versions."
        }
    }
}
