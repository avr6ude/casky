import AppKit
import UniformTypeIdentifiers

/// Open and save panels for Brewfiles. Brewfiles have no extension, so the
/// panels don't restrict or append one.
@MainActor
enum FilePanels {
    static func chooseBrewfile() -> URL? {
        choose(title: "Open Brewfile")
    }

    static func choose(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Open"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Returns an error message, or nil when saved or cancelled.
    static func saveBrewfile(_ text: String, suggestedName: String = "Brewfile") -> String? {
        save(text, title: "Export Brewfile", suggestedName: suggestedName)
    }

    /// Returns an error message, or nil when saved or cancelled.
    static func save(_ text: String, title: String, suggestedName: String) -> String? {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = suggestedName
        panel.allowsOtherFileTypes = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return "Couldn't save \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}

extension AppModel {
    func openBrewfile() {
        if let url = FilePanels.chooseBrewfile() { importBrewfile(at: url) }
    }

    func exportBrewfile(_ items: [Item]) {
        alertMessage = FilePanels.saveBrewfile(brewfile(for: items))
    }

    func exportSetup(_ setup: SavedSetup) {
        do {
            let text = String(decoding: try SetupFile.encode(setup), as: UTF8.self) + "\n"
            alertMessage = FilePanels.save(text, title: "Export Setup", suggestedName: AnsiblePlaybook.fileName(for: setup).replacingOccurrences(of: ".yml", with: ".casky.json"))
        } catch {
            alertMessage = "Couldn't export \(setup.name): \(error.localizedDescription)"
        }
    }

    /// Adds a setup from a file exported on another Mac and shows it.
    func importSetup() {
        guard let url = FilePanels.choose(title: "Import Setup") else { return }
        do {
            let setup = try SetupFile.decode(Data(contentsOf: url))
            addSetup(setup)
            revealSetup = setup.id
        } catch {
            alertMessage = "Couldn't import \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    func exportAnsible(_ setup: SavedSetup) {
        alertMessage = FilePanels.save(AnsiblePlaybook.render(setup), title: "Export Ansible Playbook", suggestedName: AnsiblePlaybook.fileName(for: setup))
    }
}
