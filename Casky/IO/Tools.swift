import Foundation

/// The user's Homebrew installation. The only way casky runs `brew` or `mas`.
struct Homebrew: Sendable {
    let executable: URL

    /// Finds `brew` at a user-chosen path, or at the standard Apple Silicon
    /// and Intel locations.
    init?(userPath: String? = nil) {
        let candidates = [userPath, "/opt/homebrew/bin/brew", "/usr/local/bin/brew"].compactMap { $0 }
        guard let path = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else { return nil }
        self.init(executable: URL(fileURLWithPath: path))
    }

    init(executable: URL) {
        self.executable = executable
    }

    /// `<prefix>/bin/brew` → `<prefix>`.
    var prefix: URL { executable.deletingLastPathComponent().deletingLastPathComponent() }

    var masExecutable: URL? {
        let url = prefix.appending(path: "bin/mas")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    /// Built from an allowlist rather than inherited: a GUI app's environment
    /// is not the user's shell anyway, and nothing else should leak into brew.
    var environment: [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var environment = ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG"].reduce(into: [String: String]()) {
            $0[$1] = inherited[$1]
        }
        environment["PATH"] = "\(prefix.path)/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        // Preflight runs `brew update` once instead of before every command.
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        return environment
    }

    func run(_ arguments: [String]) async throws -> Data {
        try await ToolRunner.run(executable, arguments: arguments, environment: environment)
    }

    func runMas(_ arguments: [String]) async throws -> Data {
        guard let mas = masExecutable else { throw ToolError.missing("mas") }
        return try await ToolRunner.run(mas, arguments: arguments, environment: environment)
    }

    func installedState() async throws -> InstalledState {
        async let brewInfo = run(["info", "--json=v2", "--installed"])
        async let tapInfo = run(["tap-info", "--json", "--installed"])
        let masList = masExecutable == nil ? nil : String(decoding: try await runMas(["list"]), as: UTF8.self)
        return try InstalledState.decode(brewInfo: try await brewInfo, tapInfo: try await tapInfo, masList: masList)
    }
}

enum ToolError: Error, Equatable {
    case missing(String)
    case launchFailed(command: String, reason: String)
    /// Keeps the tool's own message: it is what the user needs to see.
    case failed(command: String, status: Int32, stderr: String)
}

/// Runs a command to completion, without a shell and with stdin closed so a
/// prompt fails fast instead of hanging.
enum ToolRunner {
    static func run(_ executable: URL, arguments: [String], environment: [String: String]) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result {
                    try runBlocking(executable, arguments: arguments, environment: environment)
                })
            }
        }
    }

    private static func runBlocking(_ executable: URL, arguments: [String], environment: [String: String]) throws -> Data {
        let command = ([executable.lastPathComponent] + arguments).joined(separator: " ")
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ToolError.launchFailed(command: command, reason: error.localizedDescription)
        }
        // Drain stderr concurrently: a tool that fills the stderr pipe would
        // otherwise block forever while stdout is being read.
        let errors = Drain(stderr.fileHandleForReading)
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errors.wait()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ToolError.failed(
                command: command,
                status: process.terminationStatus,
                stderr: String(decoding: errorOutput, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return output
    }

    private final class Drain: @unchecked Sendable {
        private let group = DispatchGroup()
        private var data = Data()

        init(_ handle: FileHandle) {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.data = handle.readDataToEndOfFile()
                self.group.leave()
            }
        }

        func wait() -> Data {
            group.wait()
            return data
        }
    }
}
