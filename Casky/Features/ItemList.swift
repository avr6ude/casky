import SwiftUI

/// A list of installable items.
/// - Checkbox, or Return: add to / remove from the selection.
/// - Space: Quick Look-style preview, as in Finder.
/// - Double-click: install right away (or preview, if already installed).
struct ItemList: View {
    @Environment(AppModel.self) private var model
    let entries: [CatalogEntry]
    /// Show "1.0 → 2.0" on update pills instead of "Update".
    var showsUpdateVersions = false
    /// Called when the last row scrolls into view, to load more.
    var onReachEnd: (() -> Void)?
    @State private var highlighted = Set<Item>()

    var body: some View {
        List(selection: $highlighted) {
            ForEach(entries) { entry in
                ItemRow(
                    entry: entry,
                    isSelected: model.isSelected(entry.item),
                    isInstalled: model.isInstalled(entry.item),
                    isManaged: model.isManaged(entry.item),
                    update: model.updates[entry.item],
                    showsUpdateVersions: showsUpdateVersions,
                    touchID: model.touchIDForAdmin,
                    preview: { model.previewEntry = entry }
                ) {
                    model.toggle(entry.item)
                }
                .tag(entry.item)
                .onAppear {
                    if entry.id == entries.last?.id { onReachEnd?() }
                }
            }
        }
        .onKeyPress(.space) {
            guard let entry = entries.first(where: { highlighted.contains($0.item) }) else { return .ignored }
            model.previewEntry = entry
            return .handled
        }
        .onKeyPress(.return) {
            guard !highlighted.isEmpty else { return .ignored }
            model.toggleAll(items(in: highlighted))
            return .handled
        }
        .contextMenu(forSelectionType: Item.self) { clicked in
            let items = items(in: clicked)
            if items.count == 1, let entry = entries.first(where: { $0.item == items[0] }) {
                Button("Quick Look") { model.previewEntry = entry }
            }
            let missing = items.filter { !model.isInstalled($0) }
            if !missing.isEmpty {
                Button(missing.count == 1 ? "Install Now" : "Install \(missing.count) Now") {
                    Task { await model.install(missing) }
                }
                .disabled(model.isInstalling || model.homebrew == nil)
            }
            let outdated = items.filter { model.updates[$0] != nil }
            if !outdated.isEmpty {
                Button(outdated.count == 1 ? "Update Now" : "Update \(outdated.count) Now") {
                    Task { await model.update(outdated) }
                }
                .disabled(model.isInstalling)
            }
            Button(items.allSatisfy(model.isSelected) ? "Remove from Selection" : "Add to Selection") {
                model.toggleAll(items)
            }
        } primaryAction: { clicked in
            let items = items(in: clicked)
            let missing = items.filter { !model.isInstalled($0) }
            if missing.isEmpty || model.homebrew == nil {
                model.previewEntry = entries.first { clicked.contains($0.item) }
            } else if !model.isInstalling {
                Task { await model.install(missing) }
            }
        }
    }

    /// In list order, not set order.
    private func items(in set: Set<Item>) -> [Item] {
        entries.map(\.item).filter(set.contains)
    }
}

struct ItemRow: View {
    let entry: CatalogEntry
    let isSelected: Bool
    let isInstalled: Bool
    var isManaged = true
    var update: AvailableUpdate?
    var showsUpdateVersions = false
    var touchID = false
    var preview: (() -> Void)?
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Select \(entry.title)", isOn: Binding(get: { isSelected }, set: { _ in toggle() }))
                .toggleStyle(.checkbox)
                .labelsHidden()

            ItemIcon(entry: entry)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if entry.needsAdmin {
                        Pill.approval(touchID: touchID)
                            .help("This app installs with a system installer, so macOS asks you to approve it.")
                    }
                }
                if let summary = entry.summary {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            // Separators start at the name on every row; otherwise SwiftUI picks
            // whichever text it finds first (e.g. "Installed") and they jump around.
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

            Spacer(minLength: 16)

            if let update {
                (showsUpdateVersions ? Pill(text: update.versions, symbol: "arrow.down", tint: .accentColor) : Pill.update)
                    .help(update.managed
                          ? "Update available: \(update.versions)"
                          : "Update available: \(update.versions). Installed outside Homebrew; updating lets Homebrew replace and manage it.")
            } else if isInstalled {
                Pill.installed
                    .help(isManaged ? "Installed with Homebrew" : "Installed outside Homebrew, so casky leaves it alone")
            }

            Text(entry.item.kind.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .trailing)
                .help(entry.item.technicalName)

            if let preview {
                Button(action: preview) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Quick Look (Space)")
                .accessibilityLabel("Quick Look \(entry.title)")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // Children stay reachable: the checkbox selects, the info button previews.
        .accessibilityElement(children: .contain)
    }
}

/// The app's real icon when one can be found, the kind's symbol otherwise.
struct ItemIcon: View {
    let entry: CatalogEntry
    var size: CGFloat = 32
    @State private var icon: IconStore.Icon?

    var body: some View {
        Group {
            if let icon {
                let image = Image(decorative: icon.image, scale: 2).resizable().aspectRatio(contentMode: .fit)
                if icon.source == .installedApp {
                    image
                } else {
                    // Web and store artwork is usually a plain square; give it the app-icon shape.
                    image.clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
                }
            } else {
                Image(systemName: entry.item.kind.symbol)
                    .font(.system(size: size * 0.55))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .task(id: entry.item) { icon = await IconStore.shared.icon(for: entry, pixelSize: Int(size * 2)) }
    }
}
