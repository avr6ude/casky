import SwiftUI

@main
struct CaskyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentUnavailableView(
                "casky",
                systemImage: "shippingbox",
                description: Text("Pick a kit or search. casky installs everything with Homebrew and the App Store.")
            )
            .frame(minWidth: 720, minHeight: 480)
        }
    }
}
