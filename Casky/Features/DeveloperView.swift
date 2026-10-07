import SwiftUI

/// Developer tools a setup carries beyond Homebrew packages: background
/// services and editor extensions (settings restore with dotfiles).
struct DeveloperView: View {
    @Environment(AppModel.self) private var model
    let setup: SavedSetup
    /// Switches the setup to its Dotfiles tab.
    let showDotfiles: () -> Void
    @State private var adding: Editor?
    @State private var newExtension = ""
    @State private var error: String?
    @State private var capturing: Editor?

    var body: some View {
        Form {
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).textSelection(.enabled)
                }
            }
            servicesSection
            ForEach(Editor.allCases, id: \.self) { editor in
                editorSection(editor)
            }
        }
        .formStyle(.grouped)
        .task { await model.refreshDeveloperState() }
    }

    // MARK: Services

    /// This Mac's services plus the ones the setup names.
    private var serviceNames: [String] {
        (Array(model.developerState.services.keys) + (setup.services ?? []).map(\.formula.name)).uniqued().sorted()
    }

    private var servicesSection: some View {
        let names = serviceNames
        let candidates = setup.installs.compactMap { if case .formula(let ref) = $0, !names.contains(ref.name) { ref } else { nil } }
        return Section {
            ForEach(names, id: \.self) { name in
                Picker(selection: serviceBinding(name)) {
                    Text("Don't Change").tag(ServiceState?.none)
                    Divider()
                    ForEach(ServiceState.allCases, id: \.self) { Text($0.title).tag(ServiceState?.some($0)) }
                } label: {
                    Text(name)
                    if let current = model.developerState.services[name] {
                        Text("Now: \(current.title)")
                    } else {
                        Text("Not installed yet")
                    }
                }
            }
            HStack {
                Menu("Add Service") {
                    ForEach(candidates, id: \.self) { ref in
                        Button(ref.fullName) { setService(ref, .atLogin) }
                    }
                }
                .disabled(candidates.isEmpty)
                .fixedSize()
                .help(candidates.isEmpty ? "Add command-line tools to this setup first" : "A tool in this setup that runs a background service")
                Spacer()
                Button("Use This Mac's Services") {
                    model.updateSetup(setup.id) { setup in
                        setup.services = model.developerState.services.sorted { $0.key < $1.key }.compactMap { name, state in
                            (try? Ref(parsing: name)).map { ServicePolicy(formula: $0, state: state) }
                        }
                    }
                }
                .disabled(model.developerState.services.isEmpty)
            }
        } header: {
            Text("Homebrew Services")
        } footer: {
            Text("Databases and servers installed with Homebrew, such as postgresql or redis. Run at Login also starts it now.")
        }
    }

    private func serviceBinding(_ name: String) -> Binding<ServiceState?> {
        Binding {
            setup.services?.first { $0.formula.name == name }?.state
        } set: { state in
            guard let ref = (setup.services?.first { $0.formula.name == name }?.formula) ?? (try? Ref(parsing: name)) else { return }
            setService(ref, state)
        }
    }

    private func setService(_ ref: Ref, _ state: ServiceState?) {
        model.updateSetup(setup.id) { setup in
            var services = (setup.services ?? []).filter { $0.formula != ref }
            if let state { services.append(ServicePolicy(formula: ref, state: state)) }
            setup.services = services.isEmpty ? nil : services
        }
    }

    // MARK: Editors

    private func extensions(_ editor: Editor) -> [EditorExtension] {
        (setup.extensions ?? []).filter { $0.editor == editor }
    }

    private func editorSection(_ editor: Editor) -> some View {
        let saved = extensions(editor)
        let installed = model.developerState.extensions[editor]
        return Section {
            ForEach(saved, id: \.self) { editorExtension in
                LabeledContent {
                    HStack(spacing: 8) {
                        if installed?.contains(editorExtension.identifier) == true {
                            Pill.installed
                        }
                        Button {
                            model.updateSetup(setup.id) { $0.extensions?.removeAll { $0 == editorExtension } }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(editorExtension.identifier)")
                    }
                } label: {
                    Text(editorExtension.identifier).textSelection(.enabled)
                }
            }
            HStack {
                Button("Add Extension…") {
                    newExtension = ""
                    error = nil
                    adding = editor
                }
                .popover(isPresented: Binding(get: { adding == editor }, set: { if !$0 { adding = nil } })) {
                    addExtension(editor)
                }
                Spacer()
                if capturing == editor { ProgressView().controlSize(.small) }
                Button("Use This Mac's Extensions") { Task { await capture(editor) } }
                    .disabled(DeveloperTools.cli(for: editor) == nil || capturing != nil)
                    .help(DeveloperTools.cli(for: editor) == nil ? "\(editor.title) isn't installed on this Mac" : "Replace this list with the extensions \(editor.title) has now")
            }
        } header: {
            Text("\(editor.title) Extensions")
        } footer: {
            HStack(alignment: .firstTextBaseline) {
                Text("Settings, keybindings and snippets restore with Dotfiles, into ~/\(editor.userFolder).")
                Button("Set Up in Dotfiles", action: showDotfiles)
                    .buttonStyle(.link)
            }
        }
    }

    private func addExtension(_ editor: Editor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a \(editor.title) Extension").font(.headline)
            TextField("Extension ID", text: $newExtension, prompt: Text(verbatim: "ms-python.python"))
                .onSubmit { add(editor) }
            Text("The ID is under the extension's name in the Marketplace, or in its URL.")
                .font(.callout)
                .foregroundStyle(.secondary)
            if let error { Text(error).font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { adding = nil }
                Button("Add") { add(editor) }
                    .buttonStyle(.borderedProminent)
                    .disabled(newExtension.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private func add(_ editor: Editor) {
        do {
            let editorExtension = try EditorExtension(editor: editor, identifier: newExtension)
            model.updateSetup(setup.id) { setup in
                if setup.extensions?.contains(editorExtension) != true { setup.extensions = (setup.extensions ?? []) + [editorExtension] }
            }
            adding = nil
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func capture(_ editor: Editor) async {
        capturing = editor
        defer { capturing = nil }
        do {
            let found = try await DeveloperTools.installedExtensions(editor)
            model.updateSetup(setup.id) { setup in
                setup.extensions = (setup.extensions ?? []).filter { $0.editor != editor } + found
            }
            await model.refreshDeveloperState()
            error = nil
        } catch { self.error = AppModel.describe(error) }
    }
}
