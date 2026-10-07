import AppKit
import SwiftUI

/// The Mac settings a setup carries, laid out like System Settings: every
/// well-known setting with a pop-up of its values, where Don't Change leaves
/// it out of the setup. Changes save as they're made; nothing touches this
/// Mac until Apply.
struct MacPreferencesView: View {
    @Environment(AppModel.self) private var model
    let setup: SavedSetup
    @State private var preferences: [MacPreference]
    @State private var isBusy = false
    @State private var editing: CustomEdit?
    @State private var error: String?
    @State private var preview: MacPreferences.Plan?
    @State private var isBackupRestore = false

    init(setup: SavedSetup) {
        self.setup = setup
        _preferences = State(initialValue: setup.macPreferences ?? [])
    }

    private static let groups = MacPreference.presets.map(\.group).uniqued()
    private var backups: URL { model.preferencesBackupsDirectory.appending(path: setup.id.uuidString) }
    private var custom: [MacPreference] { preferences.filter { $0.preset == nil } }

    var body: some View {
        Form {
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            ForEach(Self.groups, id: \.self) { group in
                Section(group) {
                    ForEach(MacPreference.presets.filter { $0.group == group }) { preset in
                        PresetRow(preset: preset, choice: choice(for: preset))
                    }
                }
            }
            Section {
                ForEach(custom) { preference in
                    LabeledContent {
                        HStack(spacing: 8) {
                            Text(preference.describe(preference.value))
                            Menu {
                                Button("Edit…") { editing = CustomEdit(draft: PreferenceDraft(preference), original: preference.id) }
                                Button("Remove", role: .destructive) { remove(preference.id) }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .accessibilityLabel("Options for \(preference.key)")
                        }
                    } label: {
                        Text(preference.key)
                        Text(preference.domain)
                    }
                }
                Button("Add Custom Setting…") {
                    editing = CustomEdit(draft: PreferenceDraft(.init(domain: "", key: "", value: .boolean(true))), original: nil)
                }
            } header: {
                Text("Other Settings")
            } footer: {
                Text("Settings left at Don't Change aren't touched. System Default removes your change and goes back to how macOS ships. Some apps pick up changes only after reopening, or after you log out.")
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom, spacing: 0) { bar }
        .disabled(isBusy)
        .onChange(of: preferences) { save() }
        .sheet(item: $editing) { edit in
            CustomSettingSheet(draft: edit.draft, original: edit.original, taken: Set(preferences.map(\.id))) { preference in
                if let original = edit.original, let index = preferences.firstIndex(where: { $0.id == original }) {
                    preferences[index] = preference
                } else {
                    preferences.append(preference)
                }
            }
        }
        .sheet(isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } })) {
            if let preview { MacPreferencesPreviewView(plan: preview, backups: backups, isBackupRestore: isBackupRestore) }
        }
    }

    private var bar: some View {
        HStack(spacing: 12) {
            Group {
                if preferences.isEmpty {
                    Text("No settings chosen")
                } else {
                    Text("^[\(preferences.count) setting](inflect: true) in this setup")
                }
            }
            .foregroundStyle(.secondary)
            if isBusy { ProgressView().controlSize(.small) }
            Spacer()
            Menu {
                Button("Restore from Backup…", action: chooseBackup)
                Button("Show Backups in Finder") { NSWorkspace.shared.open(backups) }
                    .disabled(!FileManager.default.fileExists(atPath: backups.path))
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
            .fixedSize()
            Button("Use This Mac's Values") { Task { await capture() } }
                .disabled(preferences.isEmpty)
                .help("Set each chosen setting to what this Mac uses now")
            Button("Apply to This Mac…") { Task { await makePreview() } }
                .buttonStyle(.borderedProminent)
                .disabled(preferences.isEmpty || model.isInstalling)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: Choices

    private func choice(for preset: MacPreference.Preset) -> Binding<Choice> {
        Binding {
            guard let preference = preferences.first(where: { $0.id == preset.id }) else { return .unchanged }
            guard let value = preference.value else { return .systemDefault }
            // Show the matching option even when macOS stored 48 as 48.0.
            return .value(preset.options.first { $0.value.isSame(as: value) }?.value ?? value)
        } set: { choice in
            switch choice {
            case .unchanged: remove(preset.id)
            case .systemDefault: set(preset, nil)
            case .value(let value): set(preset, value)
            }
        }
    }

    private func set(_ preset: MacPreference.Preset, _ value: MacPreferenceValue?) {
        let preference = MacPreference(domain: preset.domain, key: preset.key, value: value)
        if let index = preferences.firstIndex(where: { $0.id == preset.id }) {
            preferences[index] = preference
        } else {
            preferences.append(preference)
        }
    }

    private func remove(_ id: String) {
        preferences.removeAll { $0.id == id }
    }

    // MARK: Actions

    private func save() {
        do {
            try model.saveMacPreferences(preferences, for: setup.id)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func capture() async {
        isBusy = true
        defer { isBusy = false }
        let current = preferences
        do {
            preferences = try await Task.detached { try MacPreferences.capture(current) }.value
        } catch { self.error = error.localizedDescription }
    }

    private func makePreview() async {
        isBusy = true
        defer { isBusy = false }
        let current = preferences
        do {
            let plan = try await Task.detached { try MacPreferences.preview(current) }.value
            isBackupRestore = false
            preview = plan
        } catch { self.error = error.localizedDescription }
    }

    private func chooseBackup() {
        let panel = NSOpenPanel()
        panel.title = "Restore Mac Preferences Backup"
        panel.directoryURL = backups
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                let plan = try await Task.detached {
                    let backup = try JSONDecoder().decode(MacPreferences.Plan.self, from: Data(contentsOf: url))
                    return try MacPreferences.restorePreview(backup)
                }.value
                isBackupRestore = true
                preview = plan
            } catch { self.error = error.localizedDescription }
        }
    }
}

// MARK: - Rows

private enum Choice: Hashable {
    case unchanged
    case systemDefault
    case value(MacPreferenceValue)
}

private struct PresetRow: View {
    let preset: MacPreference.Preset
    @Binding var choice: Choice

    var body: some View {
        Picker(preset.title, selection: $choice) {
            Text("Don't Change").tag(Choice.unchanged)
            Divider()
            ForEach(preset.options, id: \.self) { Text($0.title).tag(Choice.value($0.value)) }
            // A captured value that isn't one of the options.
            if case .value(let value) = choice, !preset.options.contains(where: { $0.value == value }) {
                Text(MacPreference(domain: preset.domain, key: preset.key, value: nil).describe(value)).tag(choice)
            }
            Divider()
            Text("System Default").tag(Choice.systemDefault)
        }
        .foregroundStyle(choice == .unchanged ? .secondary : .primary)
    }
}

private struct CustomEdit: Identifiable {
    let id = UUID()
    let draft: PreferenceDraft
    /// The setting being edited; nil when adding one.
    let original: String?
}

private struct PreferenceDraft {
    var domain: String
    var key: String
    var kind: MacPreferenceValue.Kind
    var text: String

    init(_ preference: MacPreference) {
        domain = preference.domain
        key = preference.key
        kind = preference.value?.kind ?? .systemDefault
        text = preference.value?.text ?? ""
    }

    func preference() throws -> MacPreference {
        .init(domain: domain, key: key, value: try MacPreferenceValue.parse(text, as: kind))
    }

    mutating func setKind(_ kind: MacPreferenceValue.Kind) {
        self.kind = kind
        if (try? MacPreferenceValue.parse(text, as: kind)) == nil {
            switch kind {
            case .boolean: text = "false"
            case .integer, .decimal: text = "0"
            case .systemDefault: text = ""
            case .string: break
            }
        }
    }
}

private struct CustomSettingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: PreferenceDraft
    let original: String?
    let taken: Set<String>
    let save: (MacPreference) -> Void
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Domain", text: $draft.domain, prompt: Text("com.apple.finder"))
                    TextField("Key", text: $draft.key, prompt: Text("ShowPathbar"))
                } header: {
                    Text(original == nil ? "Add a Custom Setting" : "Edit Setting")
                } footer: {
                    Text("The domain and key `defaults write` uses. NSGlobalDomain holds settings every app shares.")
                }
                Section {
                    Picker("Type", selection: Binding(get: { draft.kind }, set: { draft.setKind($0) })) {
                        ForEach(MacPreferenceValue.Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    switch draft.kind {
                    case .boolean:
                        Toggle("Value", isOn: Binding(get: { draft.text == "true" }, set: { draft.text = $0 ? "true" : "false" }))
                    case .systemDefault:
                        LabeledContent("Value", value: "Removes your change")
                    case .integer, .decimal, .string:
                        TextField("Value", text: $draft.text)
                    }
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(original == nil ? "Add" : "Save", action: commit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.domain.isEmpty || draft.key.isEmpty)
            }
            .controlSize(.large)
            .padding(20)
        }
        .frame(width: 480)
    }

    private func commit() {
        do {
            let preference = try draft.preference().validated()
            guard preference.id == original || !taken.contains(preference.id) else {
                throw MacPreferencesError.invalid("This setting is already in the setup.")
            }
            save(preference)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: - Review and apply

private struct MacPreferencesPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let plan: MacPreferences.Plan
    let backups: URL
    let isBackupRestore: Bool
    @State private var isBusy = false
    @State private var applied: MacPreferences.Applied?
    @State private var isUndone = false
    @State private var error: String?
    @State private var note: String?

    private var hasRestartableApps: Bool {
        plan.changes.contains { $0.isChanged && ($0.preference.domain == "com.apple.dock" || $0.preference.domain == "com.apple.finder" || ($0.preference.domain == "NSGlobalDomain" && $0.preference.key == "AppleShowAllExtensions")) }
    }

    private var title: String {
        if isUndone { return "Settings Restored" }
        if applied != nil { return "Settings Applied" }
        return isBackupRestore ? "Restore from Backup?" : "Apply to This Mac?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.bold())
                Text(isBackupRestore
                     ? "Puts back the values from before that change. Anything changed since in another app is left alone."
                     : "This Mac's current values are backed up first, so you can undo.")
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 24)
            Form {
                Section {
                    ForEach(plan.changes) { change in
                        LabeledContent {
                            if change.isChanged {
                                HStack(spacing: 6) {
                                    Text(change.preference.describe(change.before)).foregroundStyle(.secondary)
                                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                                    Text(change.preference.describe(change.after))
                                }
                            } else {
                                Text("Already \(change.preference.describe(change.after))").foregroundStyle(.secondary)
                            }
                        } label: {
                            Text(change.preference.title)
                            Text(change.preference.subtitle)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            footer
        }
        .frame(width: 600, height: min(560, 230 + CGFloat(plan.changes.count) * 46))
        .interactiveDismissDisabled(isBusy)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).textSelection(.enabled)
            } else if let note {
                Label(note, systemImage: "checkmark.circle.fill").foregroundStyle(.secondary)
            } else if hasRestartableApps, applied == nil {
                Text("Dock and Finder can restart afterwards to show the change.").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if isBusy {
                ProgressView().controlSize(.small)
            } else if applied != nil {
                if hasRestartableApps { Button("Restart Dock and Finder") { Task { await restart() } } }
                if !isUndone { Button("Undo") { Task { await undo() } } }
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            } else if error != nil {
                Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
            } else {
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button { Task { await apply() } } label: {
                    if plan.changedCount == 0 { Text("Nothing to Change") } else { Text("Apply ^[\(plan.changedCount) Change](inflect: true)") }
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(plan.changedCount == 0)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .padding(20)
    }

    private func apply() async {
        isBusy = true
        defer { isBusy = false }
        let plan = plan, backups = backups
        do {
            applied = try await Task.detached { try MacPreferences.apply(plan, backups: backups) }.value
            note = "Applied \(plan.changedCount) \(plan.changedCount == 1 ? "change" : "changes")."
        } catch { self.error = error.localizedDescription }
    }

    private func undo() async {
        guard let applied else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        let backups = backups
        do {
            _ = try await Task.detached {
                let reverse = try MacPreferences.restorePreview(applied.plan)
                return try MacPreferences.apply(reverse, backups: backups)
            }.value
            isUndone = true
            note = "Previous values are back."
        } catch { self.error = error.localizedDescription }
    }

    private func restart() async {
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            try await MacPreferences.restartApps(for: plan)
            note = "Dock and Finder restarted."
        } catch { self.error = AppModel.describe(error) }
    }
}
