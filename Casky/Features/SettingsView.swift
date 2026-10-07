import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var error: String?
    @State private var updateStatus = AutoUpdate.status
    @State private var updateError: String?

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

            Section {
                Toggle("Update apps automatically", isOn: Binding(
                    get: { updateStatus == .enabled || updateStatus == .requiresApproval },
                    set: setAutoUpdate
                ))
                if updateStatus == .requiresApproval {
                    HStack {
                        Text("Allow casky in Login Items to finish turning this on.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { AutoUpdate.openLoginItemsSettings() }
                    }
                }
                if let lastRun = AutoUpdate.lastRun {
                    LabeledContent("Last run") {
                        HStack {
                            Text(lastRun.formatted(date: .abbreviated, time: .shortened))
                            Button("Show Log") { NSWorkspace.shared.open(AutoUpdate.logURL) }
                        }
                    }
                }
                if let updateError {
                    Text(updateError).foregroundStyle(.red).font(.callout)
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("Every day at 9:00, while you're logged in, casky upgrades your Homebrew apps. Apps that update themselves are skipped, and anything that needs your password is left for you.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { updateStatus = AutoUpdate.status }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setAutoUpdate(_ enabled: Bool) {
        do {
            try AutoUpdate.setEnabled(enabled)
            updateError = nil
        } catch {
            updateError = "Couldn't \(enabled ? "turn on" : "turn off") automatic updates: \(error.localizedDescription)"
        }
        updateStatus = AutoUpdate.status
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
