import Foundation
import Testing
@testable import Casky

@Suite struct ApplySetupTests {
    @Test func packagesThenDotfilesThenPreferences() throws {
        let git = Item.formula(try Ref(parsing: "git"))
        let dotfiles = DotfilesConfiguration(repository: "https://example.com/dots.git", files: [try Dotfile(source: "zshrc", destination: ".zshrc")])
        let preferences = [MacPreference(domain: "com.apple.dock", key: "autohide", value: .boolean(true))]
        let setup = SavedSetup(id: UUID(), name: "Mac", items: [git], createdAt: .now, dotfiles: dotfiles, macPreferences: preferences)
        let packages = InstallPlan(selection: setup.items, installed: InstalledState())

        let plan = InstallPlan(setup: setup, packages: packages)

        #expect(plan.steps.map(\.action) == [.install(git), .dotfiles(setup: setup.id, dotfiles), .preferences(setup: setup.id, preferences)])
    }

    @Test func emptyPartsAddNoSteps() throws {
        let git = Item.formula(try Ref(parsing: "git"))
        let setup = SavedSetup(id: UUID(), name: "Mac", items: [git], createdAt: .now,
                               dotfiles: DotfilesConfiguration(repository: "https://example.com/dots.git", files: []), macPreferences: [])
        let installed = InstalledState(formulae: ["git"])
        let plan = InstallPlan(setup: setup, packages: InstallPlan(selection: setup.items, installed: installed))
        #expect(plan.steps.isEmpty)
        #expect(plan.alreadyInstalled == [git])
    }
}

@Suite struct SetupStepsTests {
    private let root = FileManager.default.temporaryDirectory.appending(path: "casky-setup-steps-\(UUID().uuidString)")

    private func git(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path, "-c", "user.name=casky", "-c", "user.email=casky@example.com", "-c", "commit.gpgsign=false"] + arguments
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test func restoresDotfilesFromARepository() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = root.appending(path: "repository"), home = root.appending(path: "home")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try "export EDITOR=vim\n".write(to: repository.appending(path: "zshrc"), atomically: true, encoding: .utf8)
        try git(["init", "-q"], in: repository)
        try git(["add", "."], in: repository)
        try git(["commit", "-q", "-m", "dotfiles"], in: repository)
        let configuration = DotfilesConfiguration(repository: repository.absoluteString, files: [try Dotfile(source: "zshrc", destination: ".zshrc")])
        let lines = Lines()

        try await SetupSteps.restoreDotfiles(configuration, checkouts: root.appending(path: "checkouts"), backups: root.appending(path: "storage/backups"), home: home, onLine: lines.append)

        let link = try FileManager.default.destinationOfSymbolicLink(atPath: home.appending(path: ".zshrc").path)
        #expect(link.hasSuffix("/zshrc"))
        #expect(lines.all.contains("Linking ~/.zshrc"))
    }

    @Test func appliesPreferencesAndReportsEachOne() async throws {
        let domain = "app.avrdude.casky.tests-\(UUID().uuidString)"
        defer {
            CFPreferencesSetValue("Size" as CFString, nil, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            try? FileManager.default.removeItem(at: root)
        }
        let preference = MacPreference(domain: domain, key: "Size", value: .integer(5))
        let lines = Lines()

        try await SetupSteps.applyPreferences([preference], backups: root, onLine: lines.append)
        try await SetupSteps.applyPreferences([preference], backups: root, onLine: lines.append)

        #expect(try MacPreferences.read(preference) == .integer(5))
        #expect(lines.all.first == "Size: System Default → 5")
        #expect(lines.all.last == "Size: already 5")
    }
}

private final class Lines: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    var all: [String] { lock.withLock { lines } }
    func append(_ line: String) { lock.withLock { lines.append(line) } }
}
