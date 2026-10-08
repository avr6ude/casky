import Foundation

/// Runs editors' command-line tools and package managers outside
/// Homebrew: listing what's there and installing what's missing.
enum DeveloperTools {
    static let applicationFolders = [URL(fileURLWithPath: "/Applications"), URL.homeDirectory.appending(path: "Applications")]

    static func cli(for editor: Editor) -> URL? {
        applicationFolders
            .map { $0.appending(path: editor.appName).appending(path: editor.cliPath) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// The editors' launchers are scripts that find their own app; they only
    /// need the basics.
    static var environment: [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var environment = ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG"].reduce(into: [String: String]()) { $0[$1] = inherited[$1] }
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        return environment
    }

    static func installedExtensions(_ editor: Editor) async throws -> [EditorExtension] {
        guard let cli = cli(for: editor) else { throw ToolError.missing(editor.title) }
        let output = try await ToolRunner.run(cli, arguments: ["--list-extensions"], environment: environment)
        return String(decoding: output, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { try? EditorExtension(editor: editor, identifier: String($0)) }
    }

    static func install(_ editorExtension: EditorExtension, onLine: @escaping @Sendable (String) -> Void) async throws -> Int32 {
        guard let cli = cli(for: editorExtension.editor) else { throw ToolError.missing(editorExtension.editor.title) }
        return try await ToolRunner.stream(cli, arguments: ["--install-extension", editorExtension.identifier], environment: environment, onLine: onLine)
    }

    /// Where package managers live: Homebrew's bin, then the per-user
    /// folders uv, pipx and rustup install into.
    static var toolFolders: [URL] {
        [URL(fileURLWithPath: "/opt/homebrew/bin"), URL(fileURLWithPath: "/usr/local/bin"),
         URL.homeDirectory.appending(path: ".local/bin"), URL.homeDirectory.appending(path: ".cargo/bin")]
    }

    static func executable(for manager: PackageManager) -> URL? {
        toolFolders.map { $0.appending(path: manager.rawValue) }.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// npm is a Node script and Cargo calls its compiler: both find their
    /// helpers through PATH.
    static var packageEnvironment: [String: String] {
        var environment = Self.environment
        environment["PATH"] = (toolFolders.map(\.path) + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]).joined(separator: ":")
        return environment
    }

    static func installedPackages(_ manager: PackageManager) async throws -> [GlobalPackage] {
        guard let tool = executable(for: manager) else { throw ToolError.missing(manager.title) }
        let arguments = switch manager {
        case .npm: ["ls", "--global", "--depth=0", "--json"]
        case .pipx: ["list", "--json"]
        case .uv: ["tool", "list"]
        case .cargo: ["install", "--list"]
        }
        let output = try await ToolRunner.run(tool, arguments: arguments, environment: packageEnvironment)
        return try DeveloperState.decodePackages(output, manager: manager).compactMap { try? GlobalPackage(manager: manager, name: $0) }
    }

    static func install(_ package: GlobalPackage, onLine: @escaping @Sendable (String) -> Void) async throws -> Int32 {
        guard let tool = executable(for: package.manager) else { throw ToolError.missing(package.manager.title) }
        return try await ToolRunner.stream(tool, arguments: package.manager.installArguments + [package.name], environment: packageEnvironment, onLine: onLine)
    }

    static func services(_ homebrew: Homebrew) async throws -> [String: ServiceState] {
        try DeveloperState.decodeServices(try await homebrew.run(["services", "info", "--all", "--json"]))
    }

    /// Everything planning needs; tools that aren't there are left out.
    static func state(homebrew: Homebrew?) async -> DeveloperState {
        var state = DeveloperState()
        if let homebrew { state.services = (try? await services(homebrew)) ?? [:] }
        for manager in PackageManager.allCases {
            if let installed = try? await installedPackages(manager) {
                state.packages[manager] = Set(installed.map(\.name))
            }
        }
        for editor in Editor.allCases {
            if let installed = try? await installedExtensions(editor) {
                state.extensions[editor] = Set(installed.map(\.identifier))
            }
        }
        return state
    }
}
