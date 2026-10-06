import AppKit

/// Fetches the official Homebrew `.pkg` from its GitHub releases. No
/// `curl | bash`: macOS Installer runs the package and asks for admin rights.
enum HomebrewInstaller {
    static func latestPackageURL(session: URLSession = .shared) async throws -> URL {
        let api = URL(string: "https://api.github.com/repos/Homebrew/brew/releases/latest")!
        let (data, response) = try await session.data(from: api)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw FetchError.http(url: api, status: status) }
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".pkg") }),
              let url = URL(string: asset.browser_download_url),
              url.host() == "github.com" else {
            throw FetchError.noInstallerPackage
        }
        return url
    }

    static func downloadLatestPackage(session: URLSession = .shared) async throws -> URL {
        let source = try await latestPackageURL(session: session)
        let (downloaded, response) = try await session.download(from: source)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw FetchError.http(url: source, status: status) }
        let destination = FileManager.default.temporaryDirectory.appending(path: source.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: downloaded, to: destination)
        return destination
    }

    @MainActor
    static func open(_ package: URL) {
        NSWorkspace.shared.open(package)
    }

    private struct Release: Decodable {
        let assets: [Asset]
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
    }
}
