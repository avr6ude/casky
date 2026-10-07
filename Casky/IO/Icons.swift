import AppKit

/// Finds a real icon for an app: the installed `.app` itself, artwork the
/// App Store publishes, or the vendor site's touch icon. Downloads are cached
/// in Caches/casky/icons; misses are remembered for a week so scrolling
/// doesn't refetch them. Command-line tools have no icon.
@MainActor
final class IconStore {
    static let shared = IconStore()

    enum Source { case installedApp, published, website }

    struct Icon {
        let image: NSImage
        let source: Source
    }

    private let memory = NSCache<NSString, NSImageBox>()
    private var inFlight: [Item: Task<Icon?, Never>] = [:]
    private let directory = URL.cachesDirectory.appending(path: "casky/icons")
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        return URLSession(configuration: configuration)
    }()

    func icon(for entry: CatalogEntry) async -> Icon? {
        if case .formula = entry.item { return nil }
        if let installed = installedIcon(entry) { return installed }
        let key = Self.key(entry.item) as NSString
        if let cached = memory.object(forKey: key) { return cached.icon }
        if let running = inFlight[entry.item] { return await running.value }

        let task = Task { await load(entry) }
        inFlight[entry.item] = task
        let icon = await task.value
        inFlight[entry.item] = nil
        memory.setObject(NSImageBox(icon), forKey: key)
        return icon
    }

    /// Checked on every call, not cached: an app installed a minute ago
    /// should show its own icon right away.
    private func installedIcon(_ entry: CatalogEntry) -> Icon? {
        guard let bundle = entry.appBundleName else { return nil }
        let candidates = [URL(fileURLWithPath: "/Applications"), URL.homeDirectory.appending(path: "Applications")]
            .map { $0.appending(path: bundle) }
        guard let app = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { return nil }
        return Icon(image: NSWorkspace.shared.icon(forFile: app.path), source: .installedApp)
    }

    private func load(_ entry: CatalogEntry) async -> Icon? {
        let file = directory.appending(path: Self.key(entry.item))
        let miss = file.appendingPathExtension("miss")
        if let image = NSImage(contentsOf: file) {
            return Icon(image: image, source: entry.iconURL != nil ? .published : .website)
        }
        if let date = (try? FileManager.default.attributesOfItem(atPath: miss.path))?[.modificationDate] as? Date,
           Date.now.timeIntervalSince(date) < 7 * 24 * 60 * 60 {
            return nil
        }

        for (url, source) in await candidates(entry) {
            guard let data = await download(url), let image = NSImage(data: data), image.isValid,
                  image.size.width >= 16 else { continue }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            return Icon(image: image, source: source)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: miss.path, contents: nil)
        return nil
    }

    /// Published artwork first. Otherwise the icons the homepage declares,
    /// then the conventional `/apple-touch-icon.png` and `/favicon.ico`.
    /// A GitHub homepage would only yield GitHub's logo, so the project
    /// owner's avatar stands in for it.
    private func candidates(_ entry: CatalogEntry) async -> [(URL, Source)] {
        if let artwork = entry.iconURL { return [(artwork, .published)] }
        guard let homepage = entry.homepage, let host = homepage.host(), homepage.scheme == "https" else { return [] }
        if host == "github.com", let owner = homepage.pathComponents.dropFirst().first,
           let avatar = URL(string: "https://github.com/\(owner).png?size=128") {
            return [(avatar, .website)]
        }
        let declared = await download(homepage, limit: 2_000_000).map { WebIcons.declared(in: $0, baseURL: homepage) } ?? []
        let conventional = ["apple-touch-icon.png", "favicon.ico"].compactMap { URL(string: "https://\(host)/\($0)") }
        return (declared + conventional).uniqued().map { ($0, .website) }
    }

    private func download(_ url: URL, limit: Int = 1_000_000) async -> Data? {
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              data.count < limit else { return nil }
        return data
    }

    private static func key(_ item: Item) -> String {
        switch item {
        case .cask(let ref): "cask-" + ref.fullName.replacingOccurrences(of: "/", with: "_")
        case .formula(let ref): "formula-" + ref.fullName.replacingOccurrences(of: "/", with: "_")
        case .mas(let id, _): "mas-\(id)"
        }
    }
}

/// NSCache needs a class value; also remembers misses (nil icon).
final class NSImageBox {
    let icon: IconStore.Icon?
    init(_ icon: IconStore.Icon?) { self.icon = icon }
}
