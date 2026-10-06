import Foundation
import Testing
@testable import Casky

@MainActor @Suite struct AppModelTests {
    private func model() -> AppModel {
        var fetch = CatalogFetch()
        fetch.cacheFile = FileManager.default.temporaryDirectory.appending(path: "casky-tests-\(UUID().uuidString)/catalog.json")
        let kit = Kit(slug: "k", symbol: "star", title: "K", summary: "", items: [.cask(try! Ref(parsing: "a")), .mas(id: 1, name: "One")])
        return AppModel(fetch: fetch, homebrew: nil, kits: [kit])
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
        let model = AppModel(fetch: fetch, homebrew: nil, kits: [])
        await model.start()
        guard case .failed = model.catalogState else { Issue.record("expected failed state"); return }
    }
}

/// Fails every request, standing in for being offline.
private final class FailingProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
