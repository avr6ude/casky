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
