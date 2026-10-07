import Foundation

/// The parts of applying a setup that aren't Homebrew commands. Each reports
/// what it did line by line, like a command's output, and throws to fail
/// the step.
enum SetupSteps {
    static func restoreDotfiles(_ configuration: DotfilesConfiguration, checkouts: URL, backups: URL, home: URL = .homeDirectory, onLine: @Sendable (String) -> Void) async throws {
        onLine("Downloading \(configuration.repository)…")
        let repository = try await DotfilesRepository.load(configuration, into: checkouts)
        let preview = try DotfilesRestore.preview(configuration, repository: repository, home: home, backups: backups)
        for change in preview.changes {
            let path = "~/" + change.file.destination.value
            switch change.action {
            case .unchanged: onLine("\(path) is already in place")
            case .create: onLine("\(change.file.mode == .link ? "Linking" : "Copying") \(path)")
            case .replace: onLine("Replacing \(path) (the original is backed up)")
            }
        }
        let result = try DotfilesRestore.apply(preview)
        onLine("Restored \(result.restored), \(result.unchanged) already in place.")
        if let backup = result.backupDirectory, result.restored > 0 { onLine("Originals: \(backup.path)") }
    }

    /// Backs up the current values, writes the new ones, then restarts Dock
    /// and Finder when their settings changed so they show.
    static func applyPreferences(_ preferences: [MacPreference], backups: URL, onLine: @Sendable (String) -> Void) async throws {
        let plan = try MacPreferences.preview(preferences)
        for change in plan.changes {
            let title = change.preference.title
            onLine(change.isChanged
                   ? "\(title): \(change.preference.describe(change.before)) → \(change.preference.describe(change.after))"
                   : "\(title): already \(change.preference.describe(change.after))")
        }
        guard plan.changedCount > 0 else { return }
        let applied = try MacPreferences.apply(plan, backups: backups)
        onLine("Originals: \(applied.backup.path)")
        let apps = MacPreferences.appsToRestart(for: plan)
        if !apps.isEmpty {
            try await MacPreferences.restartApps(for: plan)
            onLine("Restarted \(apps.formatted(.list(type: .and))).")
        }
    }
}
