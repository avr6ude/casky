import SwiftUI

/// A list of installable items. Click a checkbox, or highlight rows and press
/// Space or double-click, to add or remove them from the selection.
struct ItemList: View {
    @Environment(AppModel.self) private var model
    let entries: [CatalogEntry]
    @State private var highlighted = Set<Item>()

    var body: some View {
        List(selection: $highlighted) {
            ForEach(entries) { entry in
                ItemRow(
                    entry: entry,
                    isSelected: model.isSelected(entry.item),
                    isInstalled: model.installed.contains(entry.item)
                ) {
                    model.toggle(entry.item)
                }
                .tag(entry.item)
            }
        }
        .onKeyPress(.space) {
            guard !highlighted.isEmpty else { return .ignored }
            model.toggleAll(entries.map(\.item).filter(highlighted.contains))
            return .handled
        }
        .contextMenu(forSelectionType: Item.self) { items in
            let items = entries.map(\.item).filter(items.contains)
            Button(items.allSatisfy(model.isSelected) ? "Remove from Selection" : "Add to Selection") {
                model.toggleAll(items)
            }
        } primaryAction: { items in
            model.toggleAll(entries.map(\.item).filter(items.contains))
        }
    }
}

struct ItemRow: View {
    let entry: CatalogEntry
    let isSelected: Bool
    let isInstalled: Bool
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
                        Label("Needs your password", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("Installing this asks for your Mac password.")
                    }
                }
                if let summary = entry.summary {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if isInstalled {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }

            Text(entry.item.kind.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(entry.item.technicalName)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAction(named: isSelected ? "Remove from selection" : "Add to selection", toggle)
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
                let image = Image(nsImage: icon.image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
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
        .task(id: entry.item) { icon = await IconStore.shared.icon(for: entry) }
    }
}
