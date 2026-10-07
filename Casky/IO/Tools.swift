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
    /// Only installs get the password helper (`askpassItem`), naming the item
    /// the prompt is for.
    func environment(askpassItem: String? = nil) -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var environment = ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG"].reduce(into: [String: String]()) {
            $0[$1] = inherited[$1]
        }
        environment["PATH"] = "\(prefix.path)/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        // Preflight runs `brew update` once instead of before every command.
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        if let askpassItem, let askpass = Bundle.main.url(forResource: "askpass", withExtension: nil) {
            environment["SUDO_ASKPASS"] = askpass.path
            environment["CASKY_ASKPASS_ITEM"] = askpassItem
        }
        return environment
    }

    func run(_ arguments: [String]) async throws -> Data {
        try await ToolRunner.run(executable, arguments: arguments, environment: environment())
    }

    func runMas(_ arguments: [String]) async throws -> Data {
        guard let mas = masExecutable else { throw ToolError.missing("mas") }
        return try await ToolRunner.run(mas, arguments: arguments, environment: environment())
    }

    /// `mas get` and `mas update` need root; they go through `sudo -A` and
    /// the same password helper Homebrew uses.
    private func runMasAsRoot(_ arguments: [String], environment: [String: String], onLine: @escaping @Sendable (String) -> Void) async throws -> Int32 {
        guard let mas = masExecutable else { throw ToolError.missing("mas") }
        return try await ToolRunner.stream(URL(fileURLWithPath: "/usr/bin/sudo"), arguments: ["-A", mas.path] + arguments, environment: environment, onLine: onLine)
    }

    /// `brew outdated --greedy --json=v2`, including apps that update themselves.
    func outdated() async throws -> Data {
        try await run(["outdated", "--greedy", "--json=v2"])
    }

    /// Runs one plan step, streaming its output, and returns the exit status.
    /// App Store installs need root (`mas get` refuses otherwise), so they go
    /// through `sudo -A` and the same password helper Homebrew uses.
    func execute(_ action: InstallStep.Action, onLine: @escaping @Sendable (String) -> Void) async throws -> Int32 {
        let environment = environment(askpassItem: action.name)
        switch action {
        case .tap(let tap):
            return try await ToolRunner.stream(executable, arguments: ["tap", tap], environment: environment, onLine: onLine)
        case .install(.formula(let ref)):
            return try await ToolRunner.stream(executable, arguments: ["install", ref.fullName], environment: environment, onLine: onLine)
        case .install(.cask(let ref)):
            return try await ToolRunner.stream(executable, arguments: ["install", "--cask", ref.fullName], environment: environment, onLine: onLine)
        case .install(.mas(let id, _)):
            return try await runMasAsRoot(["get", String(id)], environment: environment, onLine: onLine)
        case .update(.formula(let ref)), .replace(.formula(let ref)):
            return try await ToolRunner.stream(executable, arguments: ["upgrade", ref.fullName], environment: environment, onLine: onLine)
        case .update(.cask(let ref)):
            // --greedy: casks that update themselves are skipped otherwise.
            return try await ToolRunner.stream(executable, arguments: ["upgrade", "--cask", "--greedy", ref.fullName], environment: environment, onLine: onLine)
        case .replace(.cask(let ref)):
            // The app wasn't installed by Homebrew; --force lets it replace it.
            return try await ToolRunner.stream(executable, arguments: ["install", "--cask", "--force", ref.fullName], environment: environment, onLine: onLine)
        case .update(.mas(let id, _)), .replace(.mas(let id, _)):
            return try await runMasAsRoot(["update", String(id)], environment: environment, onLine: onLine)
        }
    }

    func installedState() async throws -> InstalledState {
        async let brewInfo = run(["info", "--json=v2", "--installed"])
        async let tapInfo = run(["tap-info", "--json", "--installed"])
        let masList = masExecutable == nil ? nil : try await runMas(["list", "--json"])
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

    /// Runs a command with stdout and stderr merged, delivering output line by
    /// line (`\r` progress updates count as lines), and returns the exit status.
    static func stream(
        _ executable: URL,
        arguments: [String],
        environment: [String: String],
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result {
                    try streamBlocking(executable, arguments: arguments, environment: environment, onLine: onLine)
                })
            }
        }
    }

    /// Runs a command and returns its merged stdout+stderr lines, whatever
    /// the exit status. For tools such as `codesign -dv` that report on stderr.
    static func lines(_ executable: URL, arguments: [String]) async throws -> [String] {
        let collector = LineCollector()
        _ = try await stream(executable, arguments: arguments, environment: [:], onLine: collector.append)
        return collector.lines
    }

    private final class LineCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var collected: [String] = []
        var lines: [String] { lock.withLock { collected } }
        func append(_ line: String) { lock.withLock { collected.append(line) } }
    }

    private static func streamBlocking(
        _ executable: URL,
        arguments: [String],
        environment: [String: String],
        onLine: (String) -> Void
    ) throws -> Int32 {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        do {
            try process.run()
        } catch {
            let command = ([executable.lastPathComponent] + arguments).joined(separator: " ")
            throw ToolError.launchFailed(command: command, reason: error.localizedDescription)
        }
        let handle = output.fileHandleForReading
        var buffer = Data()
        func emitLines(flush: Bool) {
            while let end = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
                let line = String(decoding: buffer[buffer.startIndex..<end], as: UTF8.self)
                if !line.isEmpty { onLine(line) }
                buffer.removeSubrange(buffer.startIndex...end)
            }
            if flush, !buffer.isEmpty {
                onLine(String(decoding: buffer, as: UTF8.self))
                buffer.removeAll()
            }
        }
        while case let chunk = handle.availableData, !chunk.isEmpty {
            buffer.append(chunk)
            emitLines(flush: false)
        }
        emitLines(flush: true)
        process.waitUntilExit()
        return process.terminationStatus
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
