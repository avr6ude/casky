import Foundation
import Testing
@testable import Casky

@Suite struct EditorExtensionTests {
    @Test func validatesIDs() throws {
        #expect(try EditorExtension(editor: .vscode, identifier: " MS-Python.Python ").identifier == "ms-python.python")
        #expect(throws: DeveloperError.self) { try EditorExtension(editor: .vscode, identifier: "--install-extension") }
        #expect(throws: DeveloperError.self) { try EditorExtension(editor: .vscode, identifier: "noperiod") }
        let decoded = #"{"editor":"cursor","identifier":"-rm"}"#
        #expect(throws: (any Error).self) { try JSONDecoder().decode(EditorExtension.self, from: Data(decoded.utf8)) }
    }

    @Test func plansOnlyMissingExtensionsAfterTheirEditor() throws {
        let python = try EditorExtension(editor: .vscode, identifier: "ms-python.python")
        let go = try EditorExtension(editor: .vscode, identifier: "golang.go")
        let rust = try EditorExtension(editor: .cursor, identifier: "rust-lang.rust-analyzer")
        let setup = SavedSetup(id: UUID(), name: "Mac", items: [Editor.vscode.cask], createdAt: .now, extensions: [python, go, rust])
        let packages = InstallPlan(selection: setup.installs, installed: InstalledState())
        let developer = DeveloperState(extensions: [.vscode: ["golang.go"]])

        let plan = InstallPlan(setup: setup, packages: packages, developer: developer)

        #expect(plan.steps.map(\.action) == [.install(Editor.vscode.cask), .editorExtension(python), .editorExtension(rust)])
        #expect(plan.steps[1].prerequisites == [.install(Editor.vscode.cask)])
        #expect(plan.steps[2].prerequisites.isEmpty)
    }

    @Test func ansibleInstallsExtensionsWithTheEditorsTool() throws {
        let setup = SavedSetup(id: UUID(), name: "Mac", items: [], createdAt: .now,
                               extensions: [try EditorExtension(editor: .vscode, identifier: "ms-python.python")])
        let playbook = AnsiblePlaybook.render(setup)
        #expect(playbook.contains(#"argv: [!unsafe "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code", !unsafe "--install-extension", "{{ item }}"]"#))
        #expect(playbook.contains(#"loop: [!unsafe "ms-python.python"]"#))
    }
}
