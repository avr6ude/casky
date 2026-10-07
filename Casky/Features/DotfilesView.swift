import AppKit
import SwiftUI

/// Repository and file mappings belong to a saved setup. Editing or loading
/// only prepares a preview; home files change after Restore in that preview.
struct DotfilesView: View {
    @Environment(AppModel.self) private var model
    let setup: SavedSetup
    @State private var repositoryURL: String
    @State private var ref: String
    @State private var files: [FileDraft]
    @State private var repository: DotfilesRepository?
    @State private var isLoading = false
    @State private var isPreviewing = false
    @State private var isChoosingFile = false
    @State private var search = ""
    @State private var chosenPath: String?
    @State private var error: String?
    @State private var note: String?
    @State private var preview: DotfilesPreview?

    init(setup: SavedSetup) {
        self.setup = setup
        _repositoryURL = State(initialValue: setup.dotfiles?.repository ?? "")
        _ref = State(initialValue: setup.dotfiles?.ref ?? "")
        _files = State(initialValue: setup.dotfiles?.files.map(FileDraft.init) ?? [])
    }

    private struct FileDraft: Identifiable, Equatable {
        let id: UUID
        let source: String
        var destination: String
        var mode: Dotfile.Mode

        init(_ file: Dotfile) {
            id = file.id
            source = file.source.value
            destination = file.destination.value
            mode = file.mode
        }

        init(source: String) {
            id = UUID()
            self.source = source
            let name = (source as NSString).lastPathComponent
            destination = Self.editorDestination(for: source) ?? (name.hasPrefix(".") ? name : "." + name)
            mode = .link
        }

        /// `cursor/settings.json` belongs in Cursor's settings folder, and
        /// `vscode/keybindings.json` or `code/snippets` in VS Code's.
        static func editorDestination(for source: String) -> String? {
            let name = (source as NSString).lastPathComponent
            guard ["settings.json", "keybindings.json", "snippets"].contains(name) else { return nil }
            let folder = source.lowercased()
            let editor: Editor? = folder.contains("cursor") ? .cursor : folder.contains("vscode") || folder.contains("code") ? .vscode : nil
            return editor.map { "\($0.userFolder)/\(name)" }
        }

        func value() throws -> Dotfile {
            try Dotfile(id: id, source: source, destination: destination, mode: mode)
        }
    }

    private var isBusy: Bool { isLoading || isPreviewing }
    private var repositoryMatches: Bool {
        repository?.repository == repositoryURL.trimmingCharacters(in: .whitespacesAndNewlines)
            && repository?.ref == ref.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "doc.on.doc").font(.largeTitle).foregroundStyle(.tint).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dotfiles").font(.title.bold())
                        Text("Restore shell, Git and app configuration from a repository.").foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack {
                    Spacer()
                    Button("Save Configuration", action: save).disabled(isBusy || repositoryURL.isEmpty)
                    Button(isPreviewing ? "Checking Files…" : "Preview Restore") { Task { await makePreview() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(isBusy || !repositoryMatches || files.isEmpty || model.isInstalling)
                }
            }
            .controlSize(.large)
            .padding(24)
            Divider()
            Form {
                Section {
                    HStack(spacing: 16) {
                        Text("Repository URL").frame(width: 140, alignment: .leading)
                        TextField("Repository URL", text: $repositoryURL, prompt: Text(verbatim: "https://github.com/you/dotfiles.git"))
                            .labelsHidden()
                    }
                    HStack(spacing: 16) {
                        Text("Branch or tag").frame(width: 140, alignment: .leading)
                        TextField("Branch or tag", text: $ref, prompt: Text("Default branch"))
                            .labelsHidden()
                    }
                    HStack {
                        Button("Choose Local Repository…", action: chooseLocalRepository)
                        Spacer()
                        if isLoading { ProgressView().controlSize(.small) }
                        Button(repositoryMatches ? "Refresh Repository" : "Load Repository") { Task { await loadRepository() } }
                            .disabled(repositoryURL.isEmpty)
                    }
                } header: {
                    Text("Repository")
                } footer: {
                    Text("HTTPS works for public repositories. SSH uses your existing keys. Loading a repository downloads files; it doesn't run its scripts.")
                }
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)

                Section {
                    if files.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Choose what to restore").font(.headline)
                            Text("Load your repository, then add files or folders and choose where they belong in your home folder.")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        HStack {
                            Text("From repository").frame(width: 160, alignment: .leading)
                            Text("Destination in Home").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Method").frame(width: 94, alignment: .leading)
                            Spacer().frame(width: 24)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        ForEach($files) { $file in
                            HStack(spacing: 12) {
                                Text(file.source).lineLimit(1).truncationMode(.middle)
                                    .frame(width: 160, alignment: .leading).help(file.source)
                                HStack(spacing: 4) {
                                    Text("~/").foregroundStyle(.secondary)
                                    TextField("Destination", text: $file.destination)
                                        .labelsHidden()
                                        .accessibilityLabel("Destination for \(file.source)")
                                    Menu {
                                        ForEach(Editor.allCases, id: \.self) { editor in
                                            Section(editor.title) {
                                                ForEach(["settings.json", "keybindings.json", "snippets"], id: \.self) { name in
                                                    Button(name) { file.destination = "\(editor.userFolder)/\(name)" }
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.up.chevron.down")
                                    }
                                    .menuStyle(.borderlessButton)
                                    .menuIndicator(.hidden)
                                    .fixedSize()
                                    .help("Editor settings locations")
                                    .accessibilityLabel("Choose an editor settings location for \(file.source)")
                                }
                                Picker("Method", selection: $file.mode) {
                                    ForEach(Dotfile.Mode.allCases, id: \.self) { Text($0.title).tag($0) }
                                }
                                .labelsHidden().frame(width: 94)
                                .accessibilityLabel("Restore method for \(file.source)")
                                Button {
                                    files.removeAll { $0.id == file.id }
                                    note = nil
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove \(file.source) from this setup")
                                .accessibilityLabel("Remove \(file.source)")
                            }
                        }
                    }
                    Button("Add File or Folder…") { search = ""; chosenPath = nil; isChoosingFile = true }
                        .disabled(!repositoryMatches)
                        .popover(isPresented: $isChoosingFile) { fileChooser }
                } header: {
                    Text("Files and Folders")
                } footer: {
                    Text("Link keeps the file connected to Casky's local repository copy. Copy restores an independent file. Folder restores replace the whole folder; they don't merge its contents.")
                }

                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).textSelection(.enabled) }
                }
                if let note {
                    Section { Label(note, systemImage: "checkmark.circle").foregroundStyle(.secondary) }
                }
            }
            .formStyle(.grouped)
            .disabled(isBusy)
        }
        .sheet(isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } })) {
            if let preview { DotfilesPreviewView(preview: preview) }
        }
        .onChange(of: repositoryURL) { note = nil }
        .onChange(of: ref) { note = nil }
        .onChange(of: files) { note = nil }
    }

    private var fileChooser: some View {
        let paths = repository?.paths.filter { path in
            (search.isEmpty || path.localizedCaseInsensitiveContains(search)) && !files.contains(where: { $0.source == path })
        } ?? []
        return VStack(alignment: .leading, spacing: 12) {
            Text("Add a repository file or folder").font(.headline)
            TextField("Search paths", text: $search)
            List(paths, id: \.self, selection: $chosenPath) { path in
                Label(path, systemImage: repository?.paths.contains(where: { $0.hasPrefix(path + "/") }) == true ? "folder" : "doc")
                    .tag(path)
            }
            if paths.isEmpty { Text("No matching paths.").foregroundStyle(.secondary) }
            HStack {
                Spacer()
                Button("Cancel") { isChoosingFile = false }
                Button("Add Selected") {
                    guard let chosenPath, paths.contains(chosenPath) else { return }
                    files.append(FileDraft(source: chosenPath))
                    isChoosingFile = false
                    note = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(chosenPath.map { !paths.contains($0) } ?? true)
            }
        }
        .padding(16)
        .frame(width: 440, height: 380)
    }

    private func configuration() throws -> DotfilesConfiguration {
        try DotfilesConfiguration(repository: repositoryURL, ref: ref, files: files.map { try $0.value() }).validated()
    }

    private func save() {
        do {
            try model.saveDotfiles(configuration(), for: setup.id)
            error = nil
            note = "Dotfiles configuration saved to \(setup.name)."
        } catch { self.error = error.localizedDescription; note = nil }
    }

    private func chooseLocalRepository() {
        let panel = NSOpenPanel()
        panel.title = "Choose Dotfiles Repository"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            repositoryURL = url.absoluteString
            note = nil
        }
    }

    private func loadRepository() async {
        isLoading = true
        error = nil
        note = nil
        defer { isLoading = false }
        do {
            // File mappings may still be incomplete while editing.
            let configuration = try DotfilesConfiguration(repository: repositoryURL, ref: ref, files: []).validated()
            repository = try await DotfilesRepository.load(configuration, into: model.dotfilesDirectory.appending(path: setup.id.uuidString))
            note = "Repository loaded. Add the files and folders you want to restore."
        } catch { self.error = AppModel.describe(error) }
    }

    private func makePreview() async {
        guard let repository else { return }
        isPreviewing = true
        error = nil
        note = nil
        defer { isPreviewing = false }
        do {
            let configuration = try configuration()
            let backups = model.dotfilesBackupsDirectory
            let checked = try await Task.detached {
                try DotfilesRestore.preview(configuration, repository: repository, backups: backups)
            }.value
            try model.saveDotfiles(configuration, for: setup.id)
            preview = checked
        } catch { self.error = error.localizedDescription }
    }
}

private struct DotfilesPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: DotfilesPreview
    @State private var isRestoring = false
    @State private var result: DotfilesRestoreResult?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result == nil ? "Review Dotfiles Restore" : "Dotfiles Restored").font(.title2.bold())
            Text("Existing files and folders will be moved to a backup before replacement. Folder restores replace all contents.")
                .foregroundStyle(.secondary)
            List(preview.changes) { change in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("~/\(change.file.destination.value)").font(.headline)
                        Text("\(change.file.source.value) · \(change.file.mode.title)").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(actionTitle(change)).foregroundStyle(change.action == .replace ? .orange : .secondary)
                }
                .padding(.vertical, 4)
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).textSelection(.enabled) }
            if let result {
                Label("Restored \(result.restored); \(result.unchanged) already matched.", systemImage: "checkmark.circle")
            }
            HStack {
                if FileManager.default.fileExists(atPath: preview.backupDirectory.path) {
                    Button("Show Backups") { NSWorkspace.shared.open(preview.backupDirectory) }
                }
                Spacer()
                if isRestoring {
                    ProgressView().controlSize(.small)
                    Text("Restoring…")
                } else if result != nil || error != nil {
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                } else {
                    Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Restore \(preview.changedCount) \(preview.changedCount == 1 ? "Entry" : "Entries")") { Task { await restore() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(preview.changedCount == 0)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 680, height: 520)
        .interactiveDismissDisabled(isRestoring)
    }

    private func actionTitle(_ change: DotfilesPreview.Change) -> String {
        switch change.action {
        case .create: "Create"
        case .replace: "Replace & Back Up"
        case .unchanged: "Already Matches"
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        let preview = preview
        do {
            result = try await Task.detached { try DotfilesRestore.apply(preview) }.value
        } catch { self.error = error.localizedDescription }
    }
}
