import SwiftUI

@main
struct CaskyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("casky", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 520)
        }
        .defaultSize(width: 1280, height: 820)
        Settings {
            SettingsView()
                .environment(model)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Brewfile…") { model.openBrewfile() }
                    .keyboardShortcut("o")
                Button("Import Setup…") { model.importSetup() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Selection as Setup…") { model.promptToSaveSelection() }
                    .keyboardShortcut("s")
                    .disabled(model.selection.isEmpty)
                Button("Save This Mac as Setup…") { Task { await model.promptToSaveThisMac() } }
                Divider()
                Button("Export Brewfile…") { model.exportBrewfile(model.selection) }
                    .keyboardShortcut("e")
                    .disabled(model.selection.isEmpty)
            }
        }
    }
}
