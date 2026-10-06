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
    }
}
