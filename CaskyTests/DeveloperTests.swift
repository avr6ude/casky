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

@Suite struct ServiceTests {
    @Test func decodesWhetherServicesRunAndStartAtLogin() throws {
        let json = #"[{"name":"postgresql@16","running":true,"registered":true},{"name":"redis","running":true,"registered":false},{"name":"kubo","running":false,"registered":false}]"#
        #expect(try DeveloperState.decodeServices(Data(json.utf8)) == ["postgresql@16": .atLogin, "redis": .running, "kubo": .stopped])
    }

    @Test func plansServicesThatDifferForInstalledTools() throws {
        let redis = try Ref(parsing: "redis"), kubo = try Ref(parsing: "kubo"), missing = try Ref(parsing: "mysql")
        let setup = SavedSetup(id: UUID(), name: "Mac", items: [], createdAt: .now,
                               services: [.init(formula: redis, state: .atLogin), .init(formula: kubo, state: .stopped), .init(formula: missing, state: .atLogin)])
        let installed = InstalledState(formulae: ["redis", "kubo"])
        let plan = InstallPlan(setup: setup, packages: InstallPlan(selection: [], installed: installed), installed: installed,
                               developer: DeveloperState(services: ["redis": .running, "kubo": .stopped]))
        #expect(plan.steps.map(\.action) == [.service(redis, .atLogin)])
    }
}

@Suite struct GlobalPackageTests {
    @Test func validatesNamesPerManager() throws {
        #expect(try GlobalPackage(manager: .npm, name: "@expo/ngrok").name == "@expo/ngrok")
        #expect(try GlobalPackage(manager: .cargo, name: "diesel_cli").name == "diesel_cli")
        #expect(throws: DeveloperError.self) { try GlobalPackage(manager: .npm, name: "--prefix") }
        #expect(throws: DeveloperError.self) { try GlobalPackage(manager: .pipx, name: "a b") }
        #expect(throws: DeveloperError.self) { try GlobalPackage(manager: .cargo, name: "@scope/x") }
    }

    @Test func readsEachManagersListing() throws {
        let npm = #"{"name":"lib","dependencies":{"@expo/ngrok":{"version":"4.1.0"},"corepack":{},"npm":{},"eas-cli":{}}}"#
        #expect(try DeveloperState.decodePackages(Data(npm.utf8), manager: .npm) == ["@expo/ngrok", "eas-cli"])
        let pipx = #"{"venvs":{"black":{},"httpie":{}}}"#
        #expect(try DeveloperState.decodePackages(Data(pipx.utf8), manager: .pipx) == ["black", "httpie"])
        let uv = "ruff v0.6.0\n- ruff\nblack v24.1.0\n- black\n- blackd\n"
        #expect(try DeveloperState.decodePackages(Data(uv.utf8), manager: .uv) == ["ruff", "black"])
        #expect(try DeveloperState.decodePackages(Data("No tools installed\n".utf8), manager: .uv).isEmpty)
        let cargo = "cargo-xwin v0.20.2:\n    cargo-xwin\ndiesel_cli v2.3.7:\n    diesel\n"
        #expect(try DeveloperState.decodePackages(Data(cargo.utf8), manager: .cargo) == ["cargo-xwin", "diesel_cli"])
    }

    @Test func plansMissingPackagesAfterTheirManager() throws {
        let typescript = try GlobalPackage(manager: .npm, name: "typescript")
        let ruff = try GlobalPackage(manager: .uv, name: "ruff")
        let setup = SavedSetup(id: UUID(), name: "Mac", items: [PackageManager.npm.formula], createdAt: .now, packages: [typescript, ruff])
        let plan = InstallPlan(setup: setup, packages: InstallPlan(selection: setup.installs, installed: InstalledState()),
                               developer: DeveloperState(packages: [.uv: ["ruff"]]))
        #expect(plan.steps.map(\.action) == [.install(PackageManager.npm.formula), .globalPackage(typescript)])
        #expect(plan.steps[1].prerequisites == [.install(PackageManager.npm.formula)])
    }

    @Test func ansibleCoversDeveloperTools() throws {
        let setup = SavedSetup(id: UUID(), name: "Dev", items: [], createdAt: .now,
                               extensions: [try EditorExtension(editor: .cursor, identifier: "golang.go")],
                               services: [.init(formula: try Ref(parsing: "redis"), state: .atLogin), .init(formula: try Ref(parsing: "kubo"), state: .running)],
                               packages: [try GlobalPackage(manager: .npm, name: "typescript"), try GlobalPackage(manager: .uv, name: "ruff")])
        let playbook = AnsiblePlaybook.render(setup)
        #expect(playbook.contains("community.general.homebrew_services:"))
        #expect(playbook.contains("argv: [brew, services, run, \"{{ item }}\"]"))
        #expect(playbook.contains("community.general.npm:"))
        #expect(playbook.contains("argv: [uv, tool, install, \"{{ item }}\"]"))
        #expect(playbook.contains(#"loop: [!unsafe "golang.go"]"#))
    }
}
