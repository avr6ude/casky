import AppKit
import UniformTypeIdentifiers

/// Open and save panels for Brewfiles. Brewfiles have no extension, so the
/// panels don't restrict or append one.
@MainActor
enum FilePanels {
    static func chooseBrewfile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open Brewfile"
        panel.prompt = "Open"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Returns an error message, or nil when saved or cancelled.
    static func saveBrewfile(_ text: String, suggestedName: String = "Brewfile") -> String? {
        let panel = NSSavePanel()
        panel.title = "Export Brewfile"
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
}
