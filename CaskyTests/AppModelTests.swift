import Foundation
import Testing
@testable import Casky

@MainActor @Suite struct AppModelTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "casky-tests-\(UUID().uuidString)")

    private func model() -> AppModel {
        var fetch = CatalogFetch()
        fetch.cacheFile = directory.appending(path: "catalog.json")
        let kit = Kit(slug: "k", symbol: "star", title: "K", summary: "", items: [.cask(try! Ref(parsing: "a")), .mas(id: 1, name: "One")])
        return AppModel(fetch: fetch, store: SetupStore(file: directory.appending(path: "setups.json")), defaults: UserDefaults(suiteName: "casky-tests-\(UUID().uuidString)")!, locateHomebrew: { _ in nil }, kits: [kit])
    }

    @Test func toggleKeepsSelectionOrderAndMembership() throws {
        let model = model()
        let a = Item.cask(try Ref(parsing: "a")), b = Item.formula(try Ref(parsing: "b"))
        model.toggle(a); model.toggle(b); model.toggle(a)
        #expect(model.selection == [b])
        #expect(!model.isSelected(a) && model.isSelected(b))
    }

    @Test func toggleAllSelectsMissingThenDeselectsWhenComplete() throws {
        let model = model()
        let a = Item.cask(try Ref(parsing: "a")), b = Item.cask(try Ref(parsing: "b")), c = Item.cask(try Ref(parsing: "c"))
        model.toggle(c); model.toggle(a)
        model.toggleAll([a, b])
        #expect(model.selection == [c, a, b])
        model.toggleAll([a, b])
        #expect(model.selection == [c])
    }

    @Test func kitEntriesSkipItemsMissingFromCatalogButKeepAppStore() throws {
        let model = model()
        // No catalog loaded: Homebrew items have no entry, App Store items always show.
        #expect(model.entries(for: model.kits[0]).map(\.item) == [.mas(id: 1, name: "One")])
        #expect(model.displayEntry(for: .cask(try Ref(parsing: "a"))).title == "a")
    }

    @Test func missingCacheAndNoNetworkFailsLoudly() async {
        var fetch = CatalogFetch()
        fetch.cacheFile = FileManager.default.temporaryDirectory.appending(path: "casky-tests-\(UUID().uuidString)/catalog.json")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FailingProtocol.self]
        fetch.session = URLSession(configuration: config)
        let model = AppModel(fetch: fetch, store: SetupStore(file: directory.appending(path: "setups.json")), defaults: UserDefaults(suiteName: "casky-tests-\(UUID().uuidString)")!, locateHomebrew: { _ in nil }, kits: [])
        await model.start()
        guard case .failed = model.catalogState else { Issue.record("expected failed state"); return }
    }
}

@MainActor @Suite struct SetupTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "casky-tests-\(UUID().uuidString)")
    private var file: URL { directory.appending(path: "setups.json") }

    private func model() -> AppModel {
        var fetch = CatalogFetch()
        fetch.cacheFile = directory.appending(path: "catalog.json")
        return AppModel(fetch: fetch, store: SetupStore(file: file), defaults: UserDefaults(suiteName: "casky-tests-\(UUID().uuidString)")!, locateHomebrew: { _ in nil }, kits: [])
    }

    @Test func savedSetupsSurviveRelaunch() throws {
        let git = Item.formula(try Ref(parsing: "git"))
        let first = model()
        first.saveSetup(named: "  Work  ", items: [git])
        first.saveSetup(named: "", items: [])
        first.renameSetup(first.setups[1].id, to: "Renamed")
        first.deleteSetup(first.setups[0].id)

        let reopened = model()
        #expect(reopened.setups.map(\.name) == ["Renamed"])
        #expect(reopened.setups[0].items == [git])
    }

    @Test func unreadableFileIsNeverOverwritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: file)
        let model = model()
        #expect(model.setupsLoadError != nil)
        model.saveSetup(named: "New", items: [])
        #expect(try String(contentsOf: file, encoding: .utf8) == "not json")
    }

    @Test func importAddsPlainEntriesAndReportsTheRest() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let brewfile = directory.appending(path: "Brewfile")
        try "brew \"git\"\ncask \"firefox\"\nsystem \"x\"\n".write(to: brewfile, atomically: true, encoding: .utf8)
        let model = model()
        model.toggle(.cask(try Ref(parsing: "firefox")))
        model.importBrewfile(at: brewfile)
        #expect(model.selection == [.cask(try Ref(parsing: "firefox")), .formula(try Ref(parsing: "git"))])
        #expect(model.lastImport?.skipped == [#"system "x""#])

        model.importBrewfile(at: directory.appending(path: "missing"))
        #expect(model.alertMessage != nil)
    }
}

/// Fails every request, standing in for being offline.
private final class FailingProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
