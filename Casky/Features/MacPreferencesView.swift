import AppKit
import SwiftUI

/// The Mac settings a setup carries, laid out like System Settings: every
/// well-known setting with a pop-up of its values, where Don't Change leaves
/// it out of the setup. Changes save as they're made; nothing touches this
/// Mac until Apply, which writes straight away after backing up the
/// current values, and offers Undo.
struct MacPreferencesView: View {
    @Environment(AppModel.self) private var model
    let setup: SavedSetup
    @State private var preferences: [MacPreference]
    @State private var isBusy = false
    @State private var editing: CustomEdit?
    @State private var error: String?
    /// What the last Apply, Undo or Restore did, shown in the bar.
    @State private var outcome: Outcome?

    private struct Outcome {
        let message: String
        /// Set while the change can still be undone.
        var applied: MacPreferences.Applied?
        /// Set until Dock and Finder are restarted for this change.
        var restartPlan: MacPreferences.Plan?
        var restart: [String] { restartPlan.map(MacPreferences.appsToRestart) ?? [] }
    }

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
        .onChange(of: preferences) {
            save()
            outcome = nil
        }
        .sheet(item: $editing) { edit in
            CustomSettingSheet(draft: edit.draft, original: edit.original, taken: Set(preferences.map(\.id))) { preference in
                if let original = edit.original, let index = preferences.firstIndex(where: { $0.id == original }) {
                    preferences[index] = preference
                } else {
                    preferences.append(preference)
                }
            }
        }
    }

    private var bar: some View {
        HStack(spacing: 12) {
            if let outcome {
                Label(outcome.message, systemImage: "checkmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
                if let applied = outcome.applied {
                    Button("Undo") { Task { await undo(applied) } }
                }
                if !outcome.restart.isEmpty {
                    Button("Restart \(outcome.restart.formatted(.list(type: .and)))") { Task { await restart() } }
                        .help("Changes to these show after they restart")
                }
            } else if preferences.isEmpty {
                Text("No settings chosen").foregroundStyle(.secondary)
            } else {
                Text("^[\(preferences.count) setting](inflect: true) in this setup").foregroundStyle(.secondary)
            }
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
            Button("Apply to This Mac") { Task { await apply() } }
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
            case .custom: break
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

    /// Backs up this Mac's values, then writes the chosen ones.
    private func apply() async {
        await run { [preferences, backups] in
            let plan = try MacPreferences.preview(preferences)
            guard plan.changedCount > 0 else { return nil }
            return try MacPreferences.apply(plan, backups: backups)
        } done: { applied in
            applied.map { "Applied \(Self.count($0.plan))" } ?? "This Mac already matches"
        }
    }

    private func undo(_ applied: MacPreferences.Applied) async {
        await run { [backups] in
            try MacPreferences.apply(MacPreferences.restorePreview(applied.plan), backups: backups)
        } done: { _ in "Undone" }
        if error == nil { outcome?.applied = nil }
    }

    private func chooseBackup() {
        let panel = NSOpenPanel()
        panel.title = "Restore Mac Preferences Backup"
        panel.prompt = "Restore"
        panel.directoryURL = backups
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await run { [backups] in
                let backup = try JSONDecoder().decode(MacPreferences.Plan.self, from: Data(contentsOf: url))
                let plan = try MacPreferences.restorePreview(backup)
                guard plan.changedCount > 0 else { return nil }
                return try MacPreferences.apply(plan, backups: backups)
            } done: { applied in
                applied.map { "Restored \(Self.count($0.plan))" } ?? "This Mac already matches the backup"
            }
        }
    }

    private func restart() async {
        guard let plan = outcome?.restartPlan else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await MacPreferences.restartApps(for: plan)
            outcome?.restartPlan = nil
        } catch { self.error = AppModel.describe(error) }
    }

    /// Runs a write off the main thread and reports it in the bar.
    private func run(_ work: @escaping @Sendable () throws -> MacPreferences.Applied?, done: (MacPreferences.Applied?) -> String) async {
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            let applied = try await Task.detached(operation: work).value
            outcome = Outcome(message: done(applied), applied: applied, restartPlan: applied?.plan)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static func count(_ plan: MacPreferences.Plan) -> String {
        plan.changedCount == 1 ? "1 change" : "\(plan.changedCount) changes"
    }
}

// MARK: - Rows

private enum Choice: Hashable {
    case unchanged
    case systemDefault
    case value(MacPreferenceValue)
    /// The pop-up item that reveals a number field; never stored.
    case custom
}

/// A pop-up of the preset's values. Presets with a range also offer
/// Custom…, which shows a field and stepper for any number in it.
private struct PresetRow: View {
    let preset: MacPreference.Preset
    @Binding var choice: Choice
    @State private var wantsCustom = false

    private var number: Int? {
        if case .value(let value) = choice, let number = value.number { Int(exactly: number.rounded()) } else { nil }
    }
    private var isOffList: Bool {
        if case .value(let value) = choice { !preset.options.contains { $0.value == value } } else { false }
    }
    private var isCustom: Bool { preset.range != nil && (wantsCustom || isOffList) }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                if isCustom, let range = preset.range {
                    let value = Binding {
                        number ?? range.lowerBound
                    } set: {
                        choice = .value(.integer(min(max($0, range.lowerBound), range.upperBound)))
                    }
                    TextField("Value", value: value, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .help("\(range.lowerBound)–\(range.upperBound)")
                    Stepper("Value", value: value, in: range)
                }
                picker
            }
            .labelsHidden()
        } label: {
            Text(preset.title)
        }
        .foregroundStyle(choice == .unchanged ? .secondary : .primary)
    }

    private var picker: some View {
        Picker(preset.title, selection: Binding {
            isCustom ? .custom : choice
        } set: { new in
            if new == .custom {
                wantsCustom = true
                if number == nil, let middle = preset.options[preset.options.count / 2].value.number {
                    choice = .value(.integer(Int(middle)))
                }
            } else {
                wantsCustom = false
                choice = new
            }
        }) {
            Text("Don't Change").tag(Choice.unchanged)
            Divider()
            ForEach(preset.options, id: \.self) { Text($0.title).tag(Choice.value($0.value)) }
            if preset.range != nil {
                Text("Custom…").tag(Choice.custom)
            } else if case .value(let value) = choice, isOffList {
                // A captured value that isn't one of the options.
                Text(MacPreference(domain: preset.domain, key: preset.key, value: nil).describe(value)).tag(choice)
            }
            Divider()
            Text("System Default").tag(Choice.systemDefault)
        }
        .fixedSize()
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
