import AppKit

/// Apple's Command Line Tools, which Homebrew needs to build anything from
/// source (most formulae from third-party taps). On macOS 26 Xcode alone
/// isn't enough. Installing goes through Apple's own installer.
enum CommandLineTools {
    /// The "Install Command Line Developer Tools" prompt. It also appears
    /// when Homebrew or `xcrun` notice the tools are missing, and opens
    /// behind casky unless something brings it forward.
    static let installerBundleID = "com.apple.dt.CommandLineTools.installondemand"

    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: "/Library/Developer/CommandLineTools/usr/bin/git")
    }

    /// Whether a failed step's output is Homebrew asking for the tools.
    static func isMissing(in output: [String]) -> Bool {
        output.contains { $0.contains("xcode-select --install") || $0.contains("No developer tools installed") }
    }

    /// Opens Apple's installer and brings it to the front.
    @MainActor static func install() async {
        // Exits right away: it only launches the installer (or says the
        // tools are already there).
        _ = try? await ToolRunner.run(URL(fileURLWithPath: "/usr/bin/xcode-select"), arguments: ["--install"], environment: [:])
        for _ in 0..<20 {
            if bringInstallerForward() { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    @discardableResult @MainActor static func bringInstallerForward() -> Bool {
        guard let installer = NSRunningApplication.runningApplications(withBundleIdentifier: installerBundleID).first else { return false }
        NSApp.yieldActivation(to: installer)
        return installer.activate()
    }
}
