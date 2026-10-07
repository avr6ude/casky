import SwiftUI

/// Quick Look for an app or tool: big icon, what it is, screenshots, the
/// facts Homebrew or the App Store publish, and Install right there.
struct AppPreview: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let entry: CatalogEntry
    @State private var details: AppDetails?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let details {
                        content(details)
                    } else if let error {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .frame(width: 760, height: 640)
        .task(id: entry.item) { await load() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            ItemIcon(entry: entry, size: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title).font(.largeTitle.bold())
                Text("\(entry.item.kind.label) · \(entry.item.technicalName)")
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let summary = entry.summary {
                    Text(summary).font(.title3)
                }
                HStack(spacing: 8) {
                    if model.isInstalled(entry.item) {
                        Label("Installed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    if entry.needsAdmin {
                        Label("Admin", systemImage: "lock.fill").foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
            }
        }
    }

    @ViewBuilder private func content(_ details: AppDetails) -> some View {
        if !details.screenshots.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(details.screenshots, id: \.self) { url in
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle().fill(.fill.tertiary).aspectRatio(1.6, contentMode: .fit)
                        }
                        .frame(height: 260)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
                    }
                }
            }
            .scrollIndicators(.visible)
        }

        if !details.facts.isEmpty {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                ForEach(details.facts, id: \.self) { fact in
                    GridRow {
                        Text(fact.label).foregroundStyle(.secondary)
                        Text(fact.value).textSelection(.enabled)
                    }
                }
            }
        }

        if let about = details.about {
            Text(about)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }

        if let caveats = details.caveats {
            VStack(alignment: .leading, spacing: 8) {
                Text("After installing").font(.headline)
                ConsoleView(lines: caveats.components(separatedBy: "\n"), height: 120)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let homepage = entry.homepage {
                Link(destination: homepage) {
                    Label(entry.item.kind == .mas ? "View in App Store" : "Website", systemImage: "safari")
                }
            }
            Spacer()
            Button(model.isSelected(entry.item) ? "Remove from Selection" : "Add to Selection") {
                model.toggle(entry.item)
            }
            if !model.isInstalled(entry.item) {
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

    private func load() async {
        do {
            details = try await DetailsFetch().details(for: entry)
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = "Couldn't load details: \(AppModel.describe(error))"
        }
    }
}
