import Foundation
import Testing
@testable import Casky

@Suite struct TapNameTests {
    @Test func normalizesThirdPartyTaps() throws {
        #expect(try Ref.parseTap(" Charmbracelet/homebrew-tap ") == "charmbracelet/tap")
        #expect(try Ref.parseTap("hashicorp/tap") == "hashicorp/tap")
    }

    @Test(arguments: ["homebrew/core", "homebrew/homebrew-cask", "a", "a/b/c", "a/homebrew-", "a/b c", ""])
    func rejectsBuiltinAndMalformed(_ raw: String) {
        #expect(throws: RefError.invalid(raw)) { try Ref.parseTap(raw) }
    }

    @Test func listsRubyFilesFromGitHubContents() throws {
        let json = Data(#"[{"name": "mods.rb", "type": "file"}, {"name": "README.md", "type": "file"}, {"name": "a.rb", "type": "file"}, {"name": "sub", "type": "dir"}]"#.utf8)
        #expect(try TapListing.names(fromGitHubContents: json) == ["a", "mods"])
    }
}

@MainActor @Suite(.serialized) struct TapModelTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "casky-tests-\(UUID().uuidString)")

    private func model(responses: [String: (Int, String)]) -> AppModel {
        GitHubStub.responses = responses
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GitHubStub.self]
        var fetch = CatalogFetch()
        fetch.cacheFile = directory.appending(path: "catalog.json")
        return AppModel(
            fetch: fetch, tapFetch: TapFetch(session: URLSession(configuration: config)),
            dataDirectory: directory, defaults: UserDefaults(suiteName: "casky-tests-\(UUID().uuidString)")!,
            locateHomebrew: { _ in nil }, kits: []
        )
    }

    @Test func addsTapWithItemsThatShowAndPersist() async throws {
        let model = model(responses: [
            "/repos/charmbracelet/homebrew-tap/contents/Formula": (200, #"[{"name": "gum.rb", "type": "file"}]"#),
            "/repos/charmbracelet/homebrew-tap/contents/Casks": (200, #"[{"name": "mods.rb", "type": "file"}]"#),
        ])
        await model.addTap("charmbracelet/homebrew-tap")

        let tap = try #require(model.taps.first)
        #expect(tap.items == [.formula(try Ref(parsing: "charmbracelet/tap/gum")), .cask(try Ref(parsing: "charmbracelet/tap/mods"))])
        #expect(model.entry(for: .cask(try Ref(parsing: "charmbracelet/tap/mods")))?.summary == "From charmbracelet/tap")

        let reopened = self.model(responses: [:])
        #expect(reopened.taps == [tap])
        reopened.removeTap(tap.name)
        #expect(self.model(responses: [:]).taps.isEmpty)
    }

    @Test func fallsBackToRootFormulaeLikeOlderTaps() async throws {
        let model = model(responses: [
            "/repos/charmbracelet/homebrew-tap/contents/": (200, #"[{"name": "gum.rb", "type": "file"}, {"name": "README.md", "type": "file"}]"#),
        ])
        await model.addTap("charmbracelet/tap")
        #expect(model.taps.first?.items == [.formula(try Ref(parsing: "charmbracelet/tap/gum"))])
    }

    @Test func reportsMissingTapsAndRateLimits() async {
        let model = model(responses: ["/repos/nobody/homebrew-nothing/contents/Formula": (404, "{}"), "/repos/nobody/homebrew-nothing/contents/Casks": (404, "{}")])
        await model.addTap("nobody/nothing")
        #expect(model.taps.isEmpty)
        #expect(model.alertMessage?.contains("no Formula or Casks folder") == true)

        let limited = self.model(responses: ["/repos/a/homebrew-b/contents/Formula": (403, "{}"), "/repos/a/homebrew-b/contents/Casks": (403, "{}")])
        await limited.addTap("a/b")
        #expect(limited.alertMessage?.contains("limit") == true)
    }
}

/// Answers requests from a fixed table of path → (status, body); 404 otherwise.
private final class GitHubStub: URLProtocol {
    nonisolated(unsafe) static var responses: [String: (Int, String)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let (status, body) = Self.responses[url.path()] ?? (404, "{}")
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
