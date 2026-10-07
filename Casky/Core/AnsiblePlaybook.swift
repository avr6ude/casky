import Foundation

/// Writes a saved setup as an Ansible playbook that sets up a Mac on its own:
/// `ansible-galaxy collection install community.general`, then
/// `ansible-playbook <file>`.
///
/// Every value that came from the user is emitted as a YAML `!unsafe` string
/// so Ansible never evaluates `{{ … }}` inside it as a template.
enum AnsiblePlaybook {
    /// Where the playbook clones the dotfiles repository.
    static let dotfilesCheckout = "~/.local/share/casky/dotfiles"

    static func render(_ setup: SavedSetup) -> String {
        var tasks: [String] = []
        var handlers: Set<String> = []
        let items = setup.items.uniqued()

        let kept = items.filter { setup.rule(for: $0) != .remove }
        let taps = kept.compactMap(\.tap).uniqued()
        let names = { (kind: Item.Kind, rules: Set<PackagePolicy.Rule?>) in
            items.filter { $0.kind == kind && rules.contains(setup.rule(for: $0)) }.map(\.technicalName)
        }
        let apps = items.compactMap { if case .mas(let id, let name) = $0 { (id: id, name: name, rule: setup.rule(for: $0)) } else { nil } }
        var formulae = names(.formula, [nil, .hold])
        if apps.contains(where: { $0.rule != .remove }), !items.contains(.formula(.masTool)) { formulae.append(Ref.masTool.fullName) }

        if !taps.isEmpty {
            tasks.append(task("Add Homebrew taps", "community.general.homebrew_tap", ["name": list(taps)]))
        }
        // One task per state: present, latest (Keep Updated), absent (Remove).
        for (kind, module, noun) in [(Item.Kind.formula, "community.general.homebrew", "command-line tools"), (.cask, "community.general.homebrew_cask", "apps")] {
            let present = kind == .formula ? formulae : names(kind, [nil, .hold])
            if !present.isEmpty { tasks.append(task("Install \(noun)", module, ["name": list(present), "state": "present"])) }
            let latest = names(kind, [.keepUpdated])
            if !latest.isEmpty { tasks.append(task("Install and update \(noun)", module, ["name": list(latest), "state": "latest"])) }
            let absent = names(kind, [.remove])
            if !absent.isEmpty { tasks.append(task("Remove \(noun)", module, ["name": list(absent), "state": "absent"])) }
        }
        let held = names(.formula, [.hold])
        if !held.isEmpty {
            tasks.append(task("List held command-line tools", "ansible.builtin.command", ["argv": "[brew, list, --pinned]"], changedWhen: "false", register: "pinned", readOnly: true))
            tasks.append(task("Hold command-line tools at their versions", "ansible.builtin.command", ["argv": "[brew, pin, \"{{ item }}\"]"],
                              loop: list(held), when: "item not in pinned.stdout_lines"))
        }
        let heldApps = items.filter { $0.kind == .cask && setup.rule(for: $0) == .hold }.map(\.technicalName)
        if !heldApps.isEmpty {
            tasks.append("# Held at their version in casky (Homebrew can't pin apps): \(comment(heldApps.joined(separator: ", ")))")
        }
        for (state, rules, verb) in [("present", Set<PackagePolicy.Rule?>([nil, .hold]), "Install"), ("latest", [.keepUpdated], "Install and update"), ("absent", [.remove], "Remove")] {
            let chosen = apps.filter { rules.contains($0.rule) }
            guard !chosen.isEmpty else { continue }
            let names = chosen.map { "# \($0.id): \(comment($0.name))" }.joined(separator: "\n")
            // Removing an App Store app needs root.
            tasks.append(names + "\n" + task("\(verb) App Store apps\(state == "absent" ? "" : " (sign in to the App Store first)")", "community.general.mas",
                                              ["id": "[\(chosen.map { String($0.id) }.joined(separator: ", "))]", "state": state], become: state == "absent"))
        }

        for editor in Editor.allCases {
            let ids = (setup.extensions ?? []).filter { $0.editor == editor }.map(\.identifier)
            guard !ids.isEmpty else { continue }
            tasks.append(task("Install \(editor.title) extensions", "ansible.builtin.command",
                              ["argv": list(["/Applications/\(editor.appName)/\(editor.cliPath)", "--install-extension"]).dropLast() + ", \"{{ item }}\"]"],
                              changedWhen: quoted("'already installed' not in result.stdout"), register: "result", loop: list(ids)))
        }

        if let dotfiles = setup.dotfiles, !dotfiles.files.isEmpty {
            tasks += dotfilesTasks(dotfiles, setup: setup)
        }

        if let preferences = setup.macPreferences, !preferences.isEmpty {
            for preference in preferences {
                var arguments = ["domain": unsafe(preference.domain), "key": unsafe(preference.key)]
                if let value = preference.value {
                    arguments["type"] = switch value {
                    case .boolean: "bool"
                    case .integer: "int"
                    case .decimal: "float"
                    case .string: "string"
                    }
                    arguments["value"] = switch value {
                    case .boolean(let on): on ? "true" : "false"
                    case .integer(let number): String(number)
                    case .decimal(let number): String(number)
                    case .string(let text): unsafe(text)
                    }
                    arguments["state"] = "present"
                } else {
                    arguments["state"] = "absent"
                }
                let restart = restartHandler(for: preference)
                if let restart { handlers.insert(restart) }
                tasks.append(task("\(preference.value == nil ? "Reset" : "Set") \(comment(preference.title))", "community.general.osx_defaults", arguments, notify: restart))
            }
        }

        var playbook = """
        # Generated by casky from the setup "\(comment(setup.name))".
        # Run it on the Mac to set up:
        #   ansible-galaxy collection install community.general
        #   ansible-playbook \(fileName(for: setup))
        # Apps that use an installer package need your password; if one fails,
        # install it with `brew install --cask <name>` in Terminal.
        - name: \(quoted("Set up " + comment(setup.name)))
          hosts: localhost
          connection: local
          gather_facts: false
          environment:
            PATH: "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
          tasks:

        """
        playbook += tasks.isEmpty ? "    []\n" : tasks.map { indent($0, by: 4) }.joined(separator: "\n\n") + "\n"
        if !handlers.isEmpty {
            playbook += "\n  handlers:\n" + handlers.sorted().map { app in
                indent(task("Restart \(app)", "ansible.builtin.command", ["argv": list(["killall", app])], changedWhen: "true"), by: 4)
            }.joined(separator: "\n\n") + "\n"
        }
        return playbook
    }

    static func fileName(for setup: SavedSetup) -> String {
        let name = setup.name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let slug = String(name).split(separator: "-").joined(separator: "-")
        return (slug.isEmpty ? "setup" : slug) + ".yml"
    }

    // MARK: Dotfiles

    private static func dotfilesTasks(_ dotfiles: DotfilesConfiguration, setup: SavedSetup) -> [String] {
        let checkout = "\(dotfilesCheckout)/\(setup.id.uuidString.lowercased())"
        var git = ["repo": unsafe(dotfiles.repository), "dest": unsafe(checkout), "update": "true"]
        if !dotfiles.ref.isEmpty { git["version"] = unsafe(dotfiles.ref) }
        var tasks = [task("Download dotfiles", "ansible.builtin.git", git)]

        let parents = dotfiles.files.compactMap { file -> String? in
            let parent = (file.destination.value as NSString).deletingLastPathComponent
            return parent.isEmpty ? nil : parent
        }.uniqued()
        for parent in parents {
            tasks.append(task("Create ~/\(comment(parent))", "ansible.builtin.file", ["path": unsafe("~/" + parent), "state": "directory"]))
        }
        for file in dotfiles.files {
            let source = "\(checkout)/\(file.source.value)"
            let destination = "~/" + file.destination.value
            switch file.mode {
            case .link:
                tasks.append(task("Link ~/\(comment(file.destination.value))", "ansible.builtin.file",
                                  ["src": unsafe(source), "path": unsafe(destination), "state": "link", "force": "true"]))
            case .copy:
                // ditto copies a file onto a file and a folder's contents into
                // a folder, matching casky's own copy; `copy` would nest
                // folders. Commands get no shell, so paths are relative to ~.
                tasks.append(task("Copy ~/\(comment(file.destination.value))", "ansible.builtin.command",
                                  ["argv": list(["ditto", String(source.dropFirst(2)), file.destination.value]), "chdir": unsafe("~")], changedWhen: "true"))
            }
        }
        return tasks
    }

    // MARK: Preferences

    private static func restartHandler(for preference: MacPreference) -> String? {
        switch preference.domain {
        case "com.apple.dock": "Dock"
        case "com.apple.finder": "Finder"
        case "NSGlobalDomain" where preference.key == "AppleShowAllExtensions": "Finder"
        default: nil
        }
    }

    // MARK: YAML

    /// One task; arguments are already YAML scalars or flow sequences.
    static func task(_ name: String, _ module: String, _ arguments: [String: String], notify: String? = nil, changedWhen: String? = nil,
                     register: String? = nil, loop: String? = nil, when: String? = nil, become: Bool = false, readOnly: Bool = false) -> String {
        var lines = ["- name: \(quoted(name))", "  \(module):"]
        lines += arguments.keys.sorted().map { "    \($0): \(arguments[$0]!)" }
        if become { lines.append("  become: true") }
        // Read-only commands still run under --check, so later tasks can use their output.
        if readOnly { lines.append("  check_mode: false") }
        if let loop { lines.append("  loop: \(loop)") }
        if let when { lines.append("  when: \(quoted(when))") }
        if let register { lines.append("  register: \(register)") }
        if let changedWhen { lines.append("  changed_when: \(changedWhen)") }
        if let notify { lines.append("  notify: \(quoted("Restart \(notify)"))") }
        return lines.joined(separator: "\n")
    }

    /// A flow sequence of user values, each `!unsafe`.
    static func list(_ values: [String]) -> String {
        "[" + values.map(unsafe).joined(separator: ", ") + "]"
    }

    /// A user value Ansible must not template.
    static func unsafe(_ value: String) -> String { "!unsafe " + quoted(value) }

    /// A YAML double-quoted scalar. JSON string escaping is valid YAML.
    static func quoted(_ value: String) -> String {
        let data = try! JSONEncoder.withoutEscapingSlashes.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    /// Free text inside a `#` comment or a task name: one line, and no
    /// braces or percent signs, since Ansible templates task names.
    private static func comment(_ value: String) -> String {
        String(value.map { "{}%".contains($0) || $0.isNewline ? " " : $0 })
            .split(separator: " ").joined(separator: " ")
    }

    private static func indent(_ text: String, by spaces: Int) -> String {
        let padding = String(repeating: " ", count: spaces)
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { padding + $0 }.joined(separator: "\n")
    }
}

private extension JSONEncoder {
    static let withoutEscapingSlashes: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return encoder
    }()
}
