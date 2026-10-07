import Foundation

/// Fetches what the preview shows for one item.
struct DetailsFetch: Sendable {
    var session: URLSession = .shared

    func details(for entry: CatalogEntry) async throws -> AppDetails {
        switch entry.item {
        case .cask(let ref) where ref.tap == nil:
            var details = try AppDetails.fromCask(try await download(api("cask", ref.name)))
            if let homepage = entry.homepage, homepage.host() != "github.com",
               let html = try? await download(homepage),
               let image = WebIcons.previewImage(in: html, baseURL: homepage) {
                details.screenshots = [image]
            }
            return details
        case .formula(let ref) where ref.tap == nil:
            return try AppDetails.fromFormula(try await download(api("formula", ref.name)))
        case .mas(let id, _):
            return try AppDetails.fromAppStore(try await download(URL(string: "https://itunes.apple.com/lookup?id=\(id)")!))
        case .cask, .formula:
            // Third-party taps have no API; the catalog entry is all there is.
            return AppDetails()
        }
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
