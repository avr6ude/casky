import Foundation
import Testing
@testable import Casky

@Suite struct ToolRunnerTests {
    private let sh = URL(fileURLWithPath: "/bin/sh")

    @Test func returnsStdoutWithoutDeadlockingOnLargeStderr() async throws {
        let output = try await ToolRunner.run(sh, arguments: ["-c", "head -c 300000 /dev/zero >&2; echo ok"], environment: [:])
        #expect(String(decoding: output, as: UTF8.self) == "ok\n")
    }

    @Test func failureKeepsStatusAndStderr() async {
        await #expect(throws: ToolError.failed(command: "sh -c echo boom >&2; exit 3", status: 3, stderr: "boom")) {
            try await ToolRunner.run(sh, arguments: ["-c", "echo boom >&2; exit 3"], environment: [:])
        }
    }

    @Test func stdinIsClosedSoPromptsFailFast() async throws {
        let output = try await ToolRunner.run(sh, arguments: ["-c", "read answer || echo no-input"], environment: [:])
        #expect(String(decoding: output, as: UTF8.self) == "no-input\n")
    }

    @Test func environmentIsExactlyWhatWasPassed() async throws {
        let output = try await ToolRunner.run(URL(fileURLWithPath: "/usr/bin/env"), arguments: [], environment: ["ONLY": "this"])
        #expect(String(decoding: output, as: UTF8.self) == "ONLY=this\n")
    }
}

@Suite struct HomebrewTests {
    @Test func environmentIsAllowlisted() {
        let brew = Homebrew(executable: URL(fileURLWithPath: "/opt/homebrew/bin/brew"))
        #expect(brew.prefix.path == "/opt/homebrew")
        #expect(Set(brew.environment.keys).isSubset(of: ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "PATH", "HOMEBREW_NO_ENV_HINTS", "HOMEBREW_NO_AUTO_UPDATE"]))
        #expect(brew.environment["PATH"] == "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin")
    }

    /// Read-only smoke test against the real Homebrew on this Mac.
    @Test(.enabled(if: Homebrew() != nil)) func readsInstalledStateFromRealHomebrew() async throws {
        let state = try await #require(Homebrew()).installedState()
        #expect(!state.formulae.isEmpty || !state.casks.isEmpty)
    }
}

@Suite struct CatalogCacheTests {
    private func fetch() -> CatalogFetch {
        var fetch = CatalogFetch()
        fetch.cacheFile = FileManager.default.temporaryDirectory.appending(path: "casky-tests-\(UUID().uuidString)/catalog.json")
        return fetch
    }

    @Test func roundTripsAndReportsStaleness() throws {
        let fetch = fetch()
        let entry = CatalogEntry(item: .formula(try Ref(parsing: "git")), title: "git", summary: nil, homepage: nil, installs: 1, needsAdmin: false)
        let fetchedAt = Date(timeIntervalSince1970: 1_000_000)
        try fetch.store([entry], fetchedAt: fetchedAt)

        let fresh = try #require(fetch.cached(now: fetchedAt.addingTimeInterval(60)))
        #expect(fresh.catalog.entries == [entry] && !fresh.isStale)
        #expect(fetch.cached(now: fetchedAt.addingTimeInterval(25 * 60 * 60))?.isStale == true)
    }

    @Test func missingOrCorruptCacheMeansRefetch() throws {
        let fetch = fetch()
        #expect(fetch.cached() == nil)
        try FileManager.default.createDirectory(at: fetch.cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fetch.cacheFile)
        #expect(fetch.cached() == nil)
    }
}
