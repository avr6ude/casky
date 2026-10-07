import SwiftUI

@main
struct CaskyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("casky", id: "main") {
            RootView()
                .environment(model)
                .tint(.purple)
                .frame(minWidth: 820, minHeight: 520)
        }
        Settings {
            SettingsView()
                .environment(model)
                .tint(.purple)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Brewfile…") { model.openBrewfile() }
                    .keyboardShortcut("o")
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
