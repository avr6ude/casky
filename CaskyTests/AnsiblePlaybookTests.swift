import Foundation
import Testing
@testable import Casky

@Suite struct AnsiblePlaybookTests {
    private func setup() throws -> SavedSetup {
        SavedSetup(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Work {{ Mac }}",
            items: [.formula(try Ref(parsing: "git")), .cask(try Ref(parsing: "avr6ude/tap/casky")), .mas(id: 497799835, name: "Xcode")],
            createdAt: .now,
            dotfiles: DotfilesConfiguration(repository: "https://example.com/dots.git", ref: "main", files: [
                try Dotfile(source: "zshrc", destination: ".zshrc"),
                try Dotfile(source: "nvim", destination: ".config/nvim", mode: .copy),
            ]),
            macPreferences: [
                MacPreference(domain: "com.apple.dock", key: "autohide", value: .boolean(true)),
                MacPreference(domain: "com.example", key: "Greeting", value: .string("{{ lookup('pipe', 'id') }}")),
                MacPreference(domain: "com.example", key: "Old", value: nil),
            ]
        )
    }

    @Test func coversEveryPartOfTheSetup() throws {
        let playbook = AnsiblePlaybook.render(try setup())
        #expect(playbook.contains(#"community.general.homebrew_tap:\#n        name: [!unsafe "avr6ude/tap"]"#))
        #expect(playbook.contains(#"name: [!unsafe "git", !unsafe "mas"]"#))
        #expect(playbook.contains(#"name: [!unsafe "avr6ude/tap/casky"]"#))
        #expect(playbook.contains("id: [497799835]"))
        #expect(playbook.contains(#"repo: !unsafe "https://example.com/dots.git""#))
        #expect(playbook.contains(#"version: !unsafe "main""#))
        #expect(playbook.contains(#"path: !unsafe "~/.config""#))
        #expect(playbook.contains(#"path: !unsafe "~/.zshrc""#))
        #expect(playbook.contains(#"argv: [!unsafe "ditto", !unsafe ".local/share/casky/dotfiles/00000000-0000-0000-0000-000000000001/nvim", !unsafe ".config/nvim"]"#))
        #expect(playbook.contains(#"name: "Reset Old""#))
        #expect(playbook.contains(#"notify: "Restart Dock""#))
        #expect(playbook.contains(#"argv: [!unsafe "killall", !unsafe "Dock"]"#))
        #expect(playbook.contains("state: absent"))
    }

    @Test func userTextIsNeverTemplated() throws {
        let playbook = AnsiblePlaybook.render(try setup())
        #expect(playbook.contains(#"value: !unsafe "{{ lookup('pipe', 'id') }}""#))
        // Task names are templated, so braces from the setup name are dropped.
        #expect(!playbook.contains("{{ Mac }}"))
        #expect(playbook.contains(#"- name: "Set up Work Mac""#))
        #expect(AnsiblePlaybook.fileName(for: try setup()) == "work-mac.yml")
    }
}
