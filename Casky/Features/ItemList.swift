import SwiftUI

/// A list of installable items.
/// - Checkbox, or Return: add to / remove from the selection.
/// - Space: Quick Look-style preview, as in Finder.
/// - Double-click: install right away (or preview, if already installed).
struct ItemList: View {
    @Environment(AppModel.self) private var model
    let entries: [CatalogEntry]
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
                HStack(spacing: 6) {
                    Text(entry.title)
                        .font(.body.weight(.medium))
                    if entry.needsAdmin {
                        Label("Admin", systemImage: "lock.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.fill.tertiary, in: .capsule)
                            .help("Installing this asks for Touch ID or your Mac password.")
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

            Spacer(minLength: 12)

            if isInstalled {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .help(isManaged ? "Installed with Homebrew" : "Installed outside Homebrew, so casky leaves it alone")
            }

            Text(entry.item.kind.label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
