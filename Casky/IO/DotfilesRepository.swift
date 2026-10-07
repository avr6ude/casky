import Foundation

/// Loads a frozen checkout, reusing a clean copy of the same revision.
/// Refreshing never changes files behind existing links.
struct DotfilesRepository: Sendable {
    let directory: URL
    let repository: String
    let ref: String
    let paths: [String]
    let submodules: [DotfilePath]

    static func load(_ configuration: DotfilesConfiguration, into cacheDirectory: URL) async throws -> Self {
        let configuration = try configuration.validated()
        let directory = cacheDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        do {
            var arguments = ["clone", "--depth", "1", "--no-local"]
            if !configuration.ref.isEmpty { arguments += ["--branch", configuration.ref] }
            arguments += ["--", configuration.repository, directory.path]
            _ = try await git(arguments)
            let output = try await git(["-C", directory.path, "ls-files", "--stage", "-z"])
            var files: [String] = []
            var submodules: [DotfilePath] = []
            for record in String(decoding: output, as: UTF8.self).split(separator: "\0") {
                guard let tab = record.firstIndex(of: "\t") else {
                    throw DotfilesError.invalid("Git returned an unreadable file listing. Load the repository again.")
                }
                let path = String(record[record.index(after: tab)...])
                if record.hasPrefix("160000 ") { submodules.append(try DotfilePath(path)) } else { files.append(path) }
            }
            var paths = Set<String>()
            for file in files {
                // Unsupported names can't be selected or restored.
                guard (try? DotfilePath(file)) != nil else { continue }
                paths.insert(file)
                var components = file.split(separator: "/")
                while components.count > 1 {
                    components.removeLast()
                    paths.insert(components.joined(separator: "/"))
                }
            }
            let revision = String(decoding: try await git(["-C", directory.path, "rev-parse", "HEAD"]), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard (40...64).contains(revision.count), revision.allSatisfy({ $0.isHexDigit }) else {
                throw DotfilesError.invalid("Git returned an unreadable revision. Load the repository again.")
            }
            let existing = cacheDirectory.appending(path: revision)
            var checkout = directory
            if FileManager.default.fileExists(atPath: existing.path) {
                let retained = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
                    .filter { $0.lastPathComponent.hasPrefix(revision + "-") }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                for candidate in [existing] + retained {
                    let head = try? await git(["-C", candidate.path, "rev-parse", "HEAD"])
                    let status = try? await git(["-C", candidate.path, "status", "--porcelain", "-z", "--untracked-files=all", "--ignored"])
                    if head == Data((revision + "\n").utf8), status?.isEmpty == true {
                        try FileManager.default.removeItem(at: directory)
                        checkout = candidate
                        break
                    }
                }
                if checkout == directory {
                    // A modified checkout may be used by live links. Retain
                    // it and name the clean copy for reuse on the next load.
                    checkout = cacheDirectory.appending(path: "\(revision)-\(UUID().uuidString)")
                    try FileManager.default.moveItem(at: directory, to: checkout)
                }
            } else {
                try FileManager.default.moveItem(at: directory, to: existing)
                checkout = existing
            }
            let location = URL(fileURLWithPath: checkout.resolvingSymlinksInPath().path, isDirectory: true)
            return Self(directory: location, repository: configuration.repository, ref: configuration.ref,
                        paths: paths.sorted { $0.localizedStandardCompare($1) == .orderedAscending }, submodules: submodules)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private static func git(_ arguments: [String]) async throws -> Data {
        let inherited = ProcessInfo.processInfo.environment
        var environment = ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "SSH_AUTH_SOCK"].reduce(into: [String: String]()) {
            $0[$1] = inherited[$1]
        }
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
        environment["GIT_CONFIG_SYSTEM"] = "/dev/null"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_SSH_COMMAND"] = "/usr/bin/ssh -o BatchMode=yes"
        return try await ToolRunner.run(URL(fileURLWithPath: "/usr/bin/git"), arguments: [
            "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false", "-c", "protocol.ext.allow=never", "-c", "credential.helper=",
        ] + arguments, environment: environment)
    }
}
