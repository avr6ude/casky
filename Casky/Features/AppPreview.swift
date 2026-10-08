import SwiftUI

/// Quick Look for an app or tool: what it is, screenshots, everything
/// Homebrew, the App Store and the vendor publish about it, what it puts on
/// the Mac, and — when installed — what the copy on this Mac says about itself.
struct AppPreview: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let entry: CatalogEntry
    @State private var details: AppDetails?
    @State private var error: String?
    @State private var local: [AppDetails.Fact]?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if let details {
                        content(details)
                    } else if let error {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .frame(width: 880, height: 760)
        // Opaque, not the sheet's glass: vibrant text looks soft on
        // non-Retina displays.
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: entry.item) { await load() }
        .task(id: entry.item) { await loadLocal() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            ItemIcon(entry: entry, size: 96)
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.largeTitle.bold())
                    .textSelection(.enabled)
                if let summary = entry.summary {
                    Text(summary)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if let update = model.updates[entry.item] {
                        Pill(text: "Update \(update.versions)", symbol: "arrow.down", tint: .accentColor)
                    } else if model.isInstalled(entry.item) {
                        Pill.installed
                    }
                    if entry.needsAdmin { Pill.approval(touchID: AdminApproval.hasTouchID) }
                    Text("\(entry.item.kind.label) · \(entry.item.technicalName)")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: Content

    @ViewBuilder private func content(_ details: AppDetails) -> some View {
        if !details.screenshots.isEmpty {
            Screenshots(urls: details.screenshots)
        }
        if let about = details.about {
            ExpandableText(title: "About", text: about)
        }
        if let whatsNew = details.whatsNew {
            ExpandableText(title: "What's New", text: whatsNew)
        }

        let sections = details.sections + (local.map { [AppDetails.Section(title: "On This Mac", facts: $0)] } ?? [])
        if !sections.isEmpty {
            let columns = Self.balance(sections)
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns.indices, id: \.self) { column in
                    VStack(spacing: 16) {
                        ForEach(columns[column], id: \.self) { FactCard(section: $0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        } else if model.isInstalled(entry.item), local == nil, entry.appBundleName != nil {
            ProgressView("Reading the app on this Mac…").controlSize(.small)
        }

        ForEach(details.listings, id: \.self) { listing in
            ListingView(listing: listing)
        }

        if let caveats = details.caveats {
            VStack(alignment: .leading, spacing: 8) {
                Text("After Installing").font(.headline)
                ConsoleView(lines: caveats.components(separatedBy: "\n"), height: 120)
            }
        }
    }

    /// Two columns that stack independently, split so they end up as even
    /// as possible (a card's height ≈ its fact count plus its title). There
    /// are at most a handful of cards, so every split is tried; order is kept
    /// within each column and the first card stays on the left.
    static func balance(_ sections: [AppDetails.Section]) -> [[AppDetails.Section]] {
        let heights = sections.map { $0.facts.count + 2 }
        var best: (mask: Int, tallest: Int, difference: Int)?
        for mask in stride(from: 0, to: 1 << sections.count, by: 2) {
            var columns = [0, 0]
            for index in sections.indices { columns[(mask >> index) & 1] += heights[index] }
            let tallest = columns.max()!, difference = abs(columns[0] - columns[1])
            if best == nil || (tallest, difference) < (best!.tallest, best!.difference) {
                best = (mask, tallest, difference)
            }
        }
        let mask = best?.mask ?? 0
        return [0, 1].map { column in sections.indices.filter { (mask >> $0) & 1 == column }.map { sections[$0] } }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if let homepage = entry.homepage {
                Link(destination: homepage) {
                    Label(entry.item.kind == .mas ? "View in App Store" : "Website", systemImage: "safari")
                }
            }
            Spacer()
            Button(model.isSelected(entry.item) ? "Remove from Selection" : "Add to Selection") {
                model.toggle(entry.item)
            }
            if let update = model.updates[entry.item] {
                Button(update.managed ? "Update" : "Update with Homebrew") {
                    let item = entry.item
                    dismiss()
                    Task { await model.update([item]) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isInstalling)
                .help(update.managed ? "" : "This copy wasn't installed with Homebrew. Homebrew replaces it with \(update.latest) and keeps it updated from then on.")
            } else if !model.isInstalled(entry.item) {
                Button("Install") {
                    let item = entry.item
                    dismiss()
                    Task { await model.install([item]) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isInstalling || model.homebrew == nil)
            }
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .controlSize(.large)
        .padding(16)
    }

    // MARK: Loading

    private func load() async {
        do {
            details = try await DetailsFetch().details(for: entry)
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = "Couldn't load details: \(AppModel.describe(error))"
        }
    }

    /// Size on disk, signature and Gatekeeper checks take a moment, so they
    /// load separately from the online details.
    private func loadLocal() async {
        guard let bundle = entry.appBundleName, let app = LocalApp.location(of: bundle) else { return }
        local = await LocalApp.facts(for: app)
    }
}

// MARK: - Pieces

private struct Screenshots: View {
    let urls: [URL]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(urls, id: \.self) { url in
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle().fill(.fill.tertiary).aspectRatio(1.6, contentMode: .fit)
                    }
                    .frame(height: 300)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
                }
            }
        }
        .scrollIndicators(.visible)
    }
}

/// A heading and text that shows six lines until expanded.
private struct ExpandableText: View {
    let title: String
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text)
                .lineLimit(isExpanded ? nil : 6)
                .textSelection(.enabled)
            if text.count > 400 || text.filter(\.isNewline).count > 5 {
                Button(isExpanded ? "Less" : "More") { isExpanded.toggle() }
                    .buttonStyle(.link)
            }
        }
    }
}

private struct FactCard: View {
    let section: AppDetails.Section

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title).font(.headline)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                ForEach(section.facts, id: \.self) { fact in
                    GridRow {
                        Text(fact.label)
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        Text(fact.value)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .font(.callout)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quinary, in: .rect(cornerRadius: 12))
    }
}

private struct ListingView: View {
    let listing: AppDetails.Listing
    @State private var isExpanded = false

    var body: some View {
        let preview = 6
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(listing.title).font(.headline)
                Text("\(listing.items.count)").foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(listing.items.prefix(isExpanded ? listing.items.count : preview), id: \.self) { item in
                    Text(item)
                        .font(listing.isCode ? .callout.monospaced() : .callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            if listing.items.count > preview {
                Button(isExpanded ? "Show Less" : "Show All \(listing.items.count)") { isExpanded.toggle() }
                    .buttonStyle(.link)
            }
        }
    }
}
