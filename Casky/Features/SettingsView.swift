import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Location") {
                    Text(model.homebrew?.executable.path ?? "Not found")
                        .textSelection(.enabled)
                        .foregroundStyle(model.homebrew == nil ? .red : .primary)
                }
                HStack {
                    Button("Choose…", action: choose)
                    if model.homebrewPathOverride != nil {
                        Button("Use Standard Location") { apply(nil) }
                    }
                }
                if let error {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            } header: {
                Text("Homebrew")
            } footer: {
                Text("casky runs Homebrew with a clean environment. Proxy settings and HOMEBREW_* variables from your shell profile aren't applied.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.title = "Choose the brew command"
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.directoryURL = model.homebrew?.executable.deletingLastPathComponent() ?? URL(fileURLWithPath: "/opt/homebrew/bin")
        if panel.runModal() == .OK, let url = panel.url { apply(url) }
    }

    private func apply(_ url: URL?) {
        Task {
            do {
                try await model.setHomebrewPath(url)
                error = nil
            } catch {
                self.error = AppModel.describe(error)
            }
        }
    }
}
