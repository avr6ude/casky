import SwiftUI

/// The app, or, with `--askpass`, the admin approval `sudo` runs.
@main enum Main {
    static func main() {
        if CommandLine.arguments.dropFirst().first == "--askpass" {
            exit(MainActor.assumeIsolated { Askpass.run() })
        }
        CaskyApp.main()
    }
}
