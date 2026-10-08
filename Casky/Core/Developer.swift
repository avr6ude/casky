import Foundation

/// Code editors whose extensions a setup can carry. Their settings,
/// keybindings and snippets are plain files, restored with dotfiles.
enum Editor: String, Codable, CaseIterable, Sendable {
    case vscode, cursor

    var title: String {
        switch self {
        case .vscode: "VS Code"
        case .cursor: "Cursor"
        }
    }

    /// The Homebrew cask that installs it.
    var cask: Item {
        switch self {
        case .vscode: .cask(try! Ref(parsing: "visual-studio-code"))
        case .cursor: .cask(try! Ref(parsing: "cursor"))
        }
    }

    var appName: String {
        switch self {
        case .vscode: "Visual Studio Code.app"
        case .cursor: "Cursor.app"
        }
    }

    /// The command-line tool inside the app bundle.
    var cliPath: String {
        switch self {
        case .vscode: "Contents/Resources/app/bin/code"
        case .cursor: "Contents/Resources/app/bin/cursor"
        }
    }

    /// Where it keeps settings.json, keybindings.json and snippets/,
    /// relative to the home folder.
    var userFolder: String {
        switch self {
        case .vscode: "Library/Application Support/Code/User"
        case .cursor: "Library/Application Support/Cursor/User"
        }
    }
}

/// `publisher.name`, as `code --list-extensions` prints it. Validated on
/// the way in, including when decoded: it becomes a command argument.
struct EditorExtension: Codable, Hashable, Sendable {
    let editor: Editor
    let identifier: String

    init(editor: Editor, identifier: String) throws {
        let identifier = identifier.trimmingCharacters(in: .whitespaces).lowercased()
        guard identifier.wholeMatch(of: /[a-z0-9][a-z0-9-]*\.[a-z0-9][a-z0-9._-]*/) != nil else {
            throw DeveloperError.invalid("“\(identifier)” isn't an extension ID. Use publisher.name, such as ms-python.python.")
        }
        self.editor = editor
        self.identifier = identifier
    }

    private enum Key: String, CodingKey { case editor, identifier }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        try self.init(editor: container.decode(Editor.self, forKey: .editor), identifier: container.decode(String.self, forKey: .identifier))
    }
}

/// Package managers outside Homebrew whose global tools a setup carries.
enum PackageManager: String, Codable, CaseIterable, Sendable {
    case npm, pipx, uv, cargo

    var title: String {
        switch self {
        case .npm: "npm"
        case .pipx: "pipx"
        case .uv: "uv"
        case .cargo: "Cargo"
        }
    }

    /// The Homebrew formula that provides the manager.
    var formula: Item {
        switch self {
        case .npm: .formula(try! Ref(parsing: "node"))
        case .pipx: .formula(try! Ref(parsing: "pipx"))
        case .uv: .formula(try! Ref(parsing: "uv"))
        case .cargo: .formula(try! Ref(parsing: "rust"))
        }
    }

    var installArguments: [String] {
        switch self {
        case .npm: ["install", "--global"]
        case .pipx: ["install"]
        case .uv: ["tool", "install"]
        case .cargo: ["install"]
        }
    }

    var example: String {
        switch self {
        case .npm: "typescript"
        case .pipx, .uv: "ruff"
        case .cargo: "ripgrep"
        }
    }
}

/// A tool installed globally with npm, pipx, uv or Cargo. Validated on the
/// way in, including when decoded: the name becomes a command argument.
struct GlobalPackage: Codable, Hashable, Sendable {
    let manager: PackageManager
    let name: String

    init(manager: PackageManager, name: String) throws {
        let name = name.trimmingCharacters(in: .whitespaces)
        let valid = switch manager {
        case .npm: name.wholeMatch(of: /(@[a-z0-9~][a-z0-9._~-]*\/)?[a-z0-9~][a-z0-9._~-]*/) != nil
        case .pipx, .uv: name.wholeMatch(of: /[A-Za-z0-9][A-Za-z0-9._-]*/) != nil
        case .cargo: name.wholeMatch(of: /[A-Za-z0-9][A-Za-z0-9_-]*/) != nil
        }
        guard valid else {
            throw DeveloperError.invalid("“\(name)” isn't a \(manager.title) package name, such as \(manager.example).")
        }
        self.manager = manager
        self.name = name
    }

    private enum Key: String, CodingKey { case manager, name }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        try self.init(manager: container.decode(PackageManager.self, forKey: .manager), name: container.decode(String.self, forKey: .name))
    }
}

/// Whether a Homebrew formula's background service runs.
enum ServiceState: String, Codable, CaseIterable, Sendable {
    /// `brew services start`: runs now and starts at login.
    case atLogin
    /// `brew services run`: runs now, not at login.
    case running
    /// `brew services stop`.
    case stopped

    var title: String {
        switch self {
        case .atLogin: "Run at Login"
        case .running: "Run Now Only"
        case .stopped: "Stopped"
        }
    }
}

struct ServicePolicy: Codable, Hashable, Sendable {
    let formula: Ref
    var state: ServiceState
}

/// What's on this Mac beyond Homebrew's own packages, read before
/// planning a setup so only what's missing runs.
struct DeveloperState: Sendable {
    /// Installed extension IDs, per editor whose command-line tool was found.
    var extensions: [Editor: Set<String>] = [:]
    /// Formulae with a background service, by name, and whether it runs.
    var services: [String: ServiceState] = [:]
    /// Globally installed package names, per manager that was found.
    var packages: [PackageManager: Set<String>] = [:]
}

extension DeveloperState {
    /// Names from each manager's own listing:
    /// - npm: `npm ls --global --depth=0 --json` (its own npm and corepack left out)
    /// - pipx: `pipx list --json`
    /// - uv: `uv tool list` (`ruff v0.6.0` lines; `- ruff` lines are commands)
    /// - cargo: `cargo install --list` (`ripgrep v14.1.0:` lines; indented ones are binaries)
    static func decodePackages(_ output: Data, manager: PackageManager) throws -> [String] {
        switch manager {
        case .npm:
            let object = try JSONSerialization.jsonObject(with: output) as? [String: Any]
            let names = (object?["dependencies"] as? [String: Any])?.keys.sorted() ?? []
            return names.filter { !["npm", "corepack"].contains($0) }
        case .pipx:
            let object = try JSONSerialization.jsonObject(with: output) as? [String: Any]
            return (object?["venvs"] as? [String: Any])?.keys.sorted() ?? []
        case .uv, .cargo:
            return String(decoding: output, as: UTF8.self).split(whereSeparator: \.isNewline).compactMap { line in
                let parts = line.split(separator: " ")
                guard !line.hasPrefix(" "), !line.hasPrefix("-"), parts.count >= 2, parts[1].hasPrefix("v") else { return nil }
                return String(parts[0])
            }
        }
    }

    /// `brew services info --all --json`: `registered` means its launch
    /// agent is installed, so it starts at login.
    static func decodeServices(_ data: Data) throws -> [String: ServiceState] {
        struct Service: Decodable {
            let name: String
            let running: Bool?
            let registered: Bool?
        }
        let services = try JSONDecoder().decode([Service].self, from: data)
        return Dictionary(services.map { service in
            (service.name.lowercased(), service.registered == true ? .atLogin : service.running == true ? .running : .stopped)
        }, uniquingKeysWith: { first, _ in first })
    }
}

enum DeveloperError: LocalizedError, Equatable {
    case invalid(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}
