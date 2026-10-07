import Foundation

/// Runs editors' command-line tools: listing and installing extensions.
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

    /// Everything planning needs; tools that aren't there are left out.
    static func state() async -> DeveloperState {
        var state = DeveloperState()
        for editor in Editor.allCases {
            if let installed = try? await installedExtensions(editor) {
                state.extensions[editor] = Set(installed.map(\.identifier))
            }
        }
        return state
    }
}
