import Foundation
import Testing
@testable import Casky

@Suite struct PackagePolicyTests {
    private let git = Item.formula(try! Ref(parsing: "git"))
    private let node = Item.formula(try! Ref(parsing: "node"))
    private let zoom = Item.cask(try! Ref(parsing: "zoom"))
    private let slack = Item.cask(try! Ref(parsing: "slack"))

    private func setup(_ rules: [Item: PackagePolicy.Rule]) -> SavedSetup {
        var setup = SavedSetup(id: UUID(), name: "Mac", items: [git, node, zoom, slack], createdAt: .now)
        for (item, rule) in rules { setup.setRule(rule, for: item) }
        return setup
    }

    @Test func removalsRunFirstThenInstallsThenUpdatesAndHolds() {
        let setup = setup([zoom: .remove, git: .keepUpdated, node: .hold, slack: .hold])
        let installed = InstalledState(formulae: ["git"], casks: ["zoom"])
        let updates = [git: AvailableUpdate(item: git, installed: "2.0", latest: "2.1", managed: true)]
        let packages = InstallPlan(selection: setup.installs, installed: installed)

        let plan = InstallPlan(setup: setup, packages: packages, installed: installed, updates: updates)

        #expect(plan.steps.map(\.action) == [.remove(zoom), .install(node), .install(slack), .update(git), .hold(node), .hold(slack)])
        #expect(plan.steps.last { $0.action == .hold(node) }?.prerequisites == [.install(node)])
    }

    @Test func nothingToDoWhenAlreadyInThatState() {
        let setup = setup([zoom: .remove, git: .keepUpdated, node: .hold, slack: .hold])
        let installed = InstalledState(formulae: ["git", "node"], casks: ["slack"], pinned: ["node"])
        let packages = InstallPlan(selection: setup.installs, installed: installed)

        let plan = InstallPlan(setup: setup, packages: packages, installed: installed, updates: [:], held: [slack])

        #expect(plan.steps.isEmpty)
    }

    @Test func heldUpdatesAreNotApplied() {
        let setup = setup([git: .keepUpdated])
        let installed = InstalledState(formulae: ["git", "node"], casks: ["zoom", "slack"])
        let updates = [git: AvailableUpdate(item: git, installed: "2.0", latest: "2.1", managed: true, isHeld: true)]
        let plan = InstallPlan(setup: setup, packages: InstallPlan(selection: setup.installs, installed: installed), installed: installed, updates: updates)
        #expect(plan.steps.isEmpty)
    }

    @Test func replacingAVersionKeepsPlaceAndRule() throws {
        var setup = setup([node: .hold])
        let node22 = Item.formula(try Ref(parsing: "node@22"))
        setup.replace(node, with: node22)
        #expect(setup.items == [git, node22, zoom, slack])
        #expect(setup.rule(for: node22) == .hold)
        #expect(setup.rule(for: node) == nil)
    }

    @Test func catalogListsVersionsNewestFirst() throws {
        let entries = ["node", "node@20", "node@22", "node@18", "nodenv", "git"].map {
            CatalogEntry(item: .formula(try! Ref(parsing: $0)), title: $0, summary: nil, homepage: nil, installs: 0, needsAdmin: false)
        }
        let catalog = Catalog(entries: entries)
        #expect(catalog.versions(of: .formula(try Ref(parsing: "node@20"))).map(\.technicalName) == ["node", "node@22", "node@20", "node@18"])
        #expect(catalog.versions(of: git).isEmpty)
    }

    @Test func pinnedFormulaeComeFromBrewInfo() throws {
        let info = #"{"formulae":[{"full_name":"node","installed":[{"installed_on_request":true}],"pinned":true},{"full_name":"git","installed":[{"installed_on_request":true}],"pinned":false}],"casks":[]}"#
        let state = try InstalledState.decode(brewInfo: Data(info.utf8), tapInfo: Data("[]".utf8), masList: nil)
        #expect(state.pinned == ["node"])
        let outdated = #"{"formulae":[{"name":"node","installed_versions":["20"],"current_version":"22","pinned":true}],"casks":[]}"#
        #expect(try Updates.decodeOutdated(Data(outdated.utf8), requestedFormulae: ["node"]).first?.isHeld == true)
    }

    @Test func ansibleFollowsTheRules() {
        let playbook = AnsiblePlaybook.render(setup([zoom: .remove, git: .keepUpdated, node: .hold, slack: .hold]))
        #expect(playbook.contains(#"name: [!unsafe "node"]"# + "\n        state: present"))
        #expect(playbook.contains(#"name: [!unsafe "git"]"# + "\n        state: latest"))
        #expect(playbook.contains(#"name: [!unsafe "zoom"]"# + "\n        state: absent"))
        #expect(playbook.contains(#"loop: [!unsafe "node"]"#))
        #expect(playbook.contains("Homebrew can't pin apps): slack"))
    }
}

@Suite struct CaskVariantTests {
    private let casks = #"""
    [{"token":"ghostty","name":["Ghostty"],"desc":null,"homepage":null,"version":"1.2","deprecated":false,"disabled":false,"artifacts":[{"app":["Ghostty.app"]}],"conflicts_with":{"cask":["ghostty@tip"]}},
     {"token":"ghostty@tip","name":["Ghostty"],"desc":null,"homepage":null,"version":"tip","deprecated":false,"disabled":false,"artifacts":[{"app":["Ghostty.app"]}],"conflicts_with":{"cask":["ghostty"]}},
     {"token":"slack","name":["Slack"],"desc":null,"homepage":null,"version":"4","deprecated":false,"disabled":false,"artifacts":[],"conflicts_with":null}]
    """#

    @Test func variantsGetDistinctTitlesAndKnowTheirConflicts() throws {
        let entries = try Catalog.decodeHomebrew(casks: Data(casks.utf8), formulae: Data("[]".utf8), caskInstalls: nil, formulaInstalls: nil)
        #expect(entries.map(\.title) == ["Ghostty", "Ghostty (tip)", "Slack"])
        #expect(entries[1].conflicts == [.cask(try Ref(parsing: "ghostty"))])
        #expect(entries[2].conflicts == nil)
    }

    @Test func anInstalledVariantCountsAsInstalled() throws {
        let tip = Item.cask(try Ref(parsing: "ghostty@tip")), stable = Item.cask(try Ref(parsing: "ghostty"))
        let installed = InstalledState(casks: ["ghostty"])
        #expect(installed.isPresent(tip, appBundle: nil, conflicts: [stable]))
        let plan = InstallPlan(selection: [tip], installed: installed, conflicts: [tip: [stable]])
        #expect(plan.steps.isEmpty)
        #expect(plan.alreadyInstalled == [tip])
    }
}
