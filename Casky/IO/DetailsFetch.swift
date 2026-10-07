import Foundation

/// Fetches what the preview shows for one item, from Homebrew's API, Apple's
/// lookup API and the vendor's homepage.
struct DetailsFetch: Sendable {
    var session: URLSession = .shared

    func details(for entry: CatalogEntry) async throws -> AppDetails {
        switch entry.item {
        case .cask(let ref) where ref.tap == nil:
            var details = try AppDetails.fromCask(try await download(api("cask", ref.name)))
            async let size = downloadSize(details.downloadURL)
            async let page = homepage(entry)
            if let size = await size {
                details.sections[0].facts.insert(AppDetails.Fact(label: "Download size", value: size.formatted(.byteCount(style: .file))), at: 1)
            }
            let (about, image) = await page
            details.about = about
            details.screenshots = image.map { [$0] } ?? []
            return details
        case .formula(let ref) where ref.tap == nil:
            return try AppDetails.fromFormula(try await download(api("formula", ref.name)))
        case .mas(let id, _):
            return try AppDetails.fromAppStore(try await download(URL(string: "https://itunes.apple.com/lookup?id=\(id)")!))
        case .cask, .formula:
            // Third-party taps have no API; the homepage is all there is.
            let (about, image) = await homepage(entry)
            return AppDetails(about: about, screenshots: image.map { [$0] } ?? [])
        }
    }

    /// The homepage's description and share image. GitHub pages describe
    /// GitHub, not the project, so they're skipped.
    private func homepage(_ entry: CatalogEntry) async -> (String?, URL?) {
        guard let homepage = entry.homepage, homepage.host() != "github.com",
              let html = try? await download(homepage) else { return (nil, nil) }
        return (WebPage.description(in: html), WebPage.previewImage(in: html, baseURL: homepage))
    }

    /// From a HEAD request, following redirects to the CDN.
    private func downloadSize(_ url: URL?) async -> Int64? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.expectedContentLength > 0 else { return nil }
        return http.expectedContentLength
    }

    private func api(_ kind: String, _ name: String) -> URL {
        URL(string: "https://formulae.brew.sh/api/\(kind)/\(name).json")!
    }

    private func download(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw FetchError.http(url: url, status: status) }
        return data
    }
}
