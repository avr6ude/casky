import SwiftUI

/// Developer tools a setup carries beyond Homebrew packages: editor
/// extensions (settings restore with dotfiles).
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
            ForEach(Editor.allCases, id: \.self) { editor in
                editorSection(editor)
            }
        }
        .formStyle(.grouped)
        .task { await model.refreshDeveloperState() }
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
