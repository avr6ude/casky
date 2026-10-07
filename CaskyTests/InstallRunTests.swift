import Foundation
import Testing
@testable import Casky

/// Drives the real run loop against a fake `brew` script, so nothing is
/// installed. App Store steps are left out: they go through real `sudo`.
@MainActor @Suite struct InstallRunTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "casky-tests-\(UUID().uuidString)")

    private func fakeBrew() throws -> Homebrew {
        let bin = directory.appending(path: "bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let script = bin.appending(path: "brew")
        try """
        #!/bin/sh
        case "$1" in
          update) echo "offline" >&2; exit 1 ;;
          --version) echo "Homebrew 7.0.8" ;;
          info) echo '{"formulae": [], "casks": [{"full_token": "present"}]}' ;;
          tap-info) echo '[]' ;;
          tap) echo "==> Tapping $2" ;;
          install)
            shift
            [ "$1" = "--cask" ] && shift
            case "$1" in
              *bad*) echo "Error: $1 is not available"; exit 1 ;;
              *) printf '==> Downloading %s\\r==> Installing %s\\n' "$1" "$1" ;;
            esac ;;
          *) exit 64 ;;
        esac
        """.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return Homebrew(executable: script)
    }

    private func model(_ brew: Homebrew) -> AppModel {
        var fetch = CatalogFetch()
        fetch.cacheFile = directory.appending(path: "catalog.json")
        return AppModel(fetch: fetch, dataDirectory: directory, defaults: UserDefaults(suiteName: "casky-tests-\(UUID().uuidString)")!, locateHomebrew: { _ in brew }, kits: [])
    }

    @Test func installsInOrderRecordsFailuresAndSkipsInstalled() async throws {
        let model = model(try fakeBrew())
        let good = Item.cask(try Ref(parsing: "good"))
        let bad = Item.cask(try Ref(parsing: "x/y/bad"))
        let tool = Item.formula(try Ref(parsing: "x/y/tool"))
        let present = Item.cask(try Ref(parsing: "present"))
        for item in [good, bad, tool, present] { model.toggle(item) }

        await model.install()
        let run = try #require(model.run)

        #expect(run.plan.alreadyInstalled == [present])
        #expect(run.outcomes[.tap("x/y")] == .installed)
        #expect(run.outcomes[.install(tool)] == .installed)
        #expect(run.outcomes[.install(good)] == .installed)
        #expect(run.outcomes[.install(bad)] == .failed(status: 1, output: ["Error: x/y/bad is not available"]))
        #expect(run.isFinished && !model.isInstalling)
        #expect(model.runNote?.contains("offline") == true)

        model.dismissRun()
        #expect(model.run == nil)

        // The run is in the history, and the history survives a relaunch.
        let record = try #require(self.model(try fakeBrew()).history.first)
        #expect(record.installedCount == 3 && record.failedCount == 1 && record.alreadyInstalled == 1)
        #expect(record.steps.map(\.title) == ["x/y", "tool", "good", "bad"])
    }

    @Test func settingsAcceptOnlyHomebrew() async throws {
        let brew = try fakeBrew()
        let defaults = UserDefaults(suiteName: "casky-tests-\(UUID().uuidString)")!
        var fetch = CatalogFetch()
        fetch.cacheFile = directory.appending(path: "catalog.json")
        let model = AppModel(fetch: fetch, dataDirectory: directory, defaults: defaults, locateHomebrew: { _ in nil }, kits: [])

        await #expect(throws: AppModel.SettingsError.notHomebrew("/bin/echo")) {
            try await model.setHomebrewPath(URL(fileURLWithPath: "/bin/echo"))
        }
        #expect(model.homebrew == nil && model.homebrewPathOverride == nil)

        try await model.setHomebrewPath(brew.executable)
        #expect(model.homebrew?.executable == brew.executable)
        #expect(model.homebrewPathOverride == brew.executable.path)
        #expect(model.installed.casks == ["present"])

        try await model.setHomebrewPath(nil)
        #expect(model.homebrewPathOverride == nil && model.homebrew == nil)
    }

    @Test func stopRequestedMidRunSkipsTheRest() async throws {
        let model = model(try fakeBrew())
        let items = try ["one", "two", "three"].map { Item.cask(try Ref(parsing: $0)) }
        for item in items { model.toggle(item) }

        let install = Task { await model.install() }
        while model.run?.current == nil { await Task.yield() }
        model.stopAfterCurrentStep()
        await install.value

        let run = try #require(model.run)
        #expect(run.outcomes[.install(items[0])] == .installed)
        #expect(run.outcomes[.install(items[2])] == .skipped(reason: "Stopped"))
    }
}
