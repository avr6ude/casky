import Foundation
import Testing
@testable import Casky

@Suite struct SetupFileTests {
    private func fullSetup() throws -> SavedSetup {
        let node = Item.formula(try Ref(parsing: "node"))
        var setup = SavedSetup(
            id: UUID(), name: "Work", items: [node, .cask(try Ref(parsing: "zoom")), .mas(id: 497799835, name: "Xcode")], createdAt: .distantPast,
            dotfiles: DotfilesConfiguration(repository: "https://example.com/dots.git", ref: "main", files: [try Dotfile(source: "zshrc", destination: ".zshrc")]),
            macPreferences: [MacPreference(domain: "com.apple.dock", key: "autohide", value: .boolean(true))],
            extensions: [try EditorExtension(editor: .vscode, identifier: "golang.go")],
            services: [ServicePolicy(formula: try Ref(parsing: "redis"), state: .atLogin)],
            packages: [try GlobalPackage(manager: .npm, name: "typescript")]
        )
        setup.setRule(.hold, for: node)
        return setup
    }

    @Test func roundTripsEverythingWithANewIdentity() throws {
        let setup = try fullSetup()
        let now = Date(timeIntervalSince1970: 1_000)
        let imported = try SetupFile.decode(SetupFile.encode(setup), now: now)

        #expect(imported.id != setup.id)
        #expect(imported.createdAt == now)
        #expect(imported.name == setup.name)
        #expect(imported.items == setup.items)
        #expect(imported.policies == setup.policies)
        #expect(imported.dotfiles == setup.dotfiles)
        #expect(imported.macPreferences == setup.macPreferences)
        #expect(imported.extensions == setup.extensions)
        #expect(imported.services == setup.services)
        #expect(imported.packages == setup.packages)
    }

    @Test func rejectsOtherFilesAndNewerVersions() throws {
        #expect(throws: SetupFileError.unreadable) { try SetupFile.decode(Data(#"{"cask":"zoom"}"#.utf8)) }
        var json = String(decoding: try SetupFile.encode(try fullSetup()), as: UTF8.self)
        json = json.replacingOccurrences(of: #""version" : 1"#, with: #""version" : 2"#)
        #expect(throws: SetupFileError.newer) { try SetupFile.decode(Data(json.utf8)) }
    }

    @Test func validatesWhatItReads() throws {
        let base = String(decoding: try SetupFile.encode(try fullSetup()), as: UTF8.self)
        for (good, bad) in [(#""typescript""#, #""--prefix""#), (#""golang.go""#, #""-rf""#), (#""com.apple.dock""#, #""bad domain""#), (#"".zshrc""#, #""../.zshrc""#)] {
            #expect(throws: (any Error).self) { try SetupFile.decode(Data(base.replacingOccurrences(of: good, with: bad).utf8)) }
        }
    }

    @Test func dropsRulesForItemsNotInTheSetup() throws {
        var setup = try fullSetup()
        setup.setRule(.remove, for: .formula(try Ref(parsing: "git")))
        let imported = try SetupFile.decode(SetupFile.encode(setup))
        #expect(imported.policies?.map(\.item) == [.formula(try Ref(parsing: "node"))])
    }
}
