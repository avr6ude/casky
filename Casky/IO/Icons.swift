import AppKit
import ImageIO

/// Finds a real icon for an app: the installed `.app` itself, artwork the
/// App Store publishes, or the vendor site's icons. Everything — file checks,
/// downloads, decoding — happens off the main thread, and images come back
/// as thumbnails at the size they're drawn, so scrolling never decodes or
/// scales a 1024px icon. Downloads are cached in Caches/casky/icons; misses
/// are remembered for a week. Command-line tools have no icon.
actor IconStore {
    static let shared = IconStore()

    enum Source: Sendable { case installedApp, published, website }

    struct Icon: Sendable {
        let image: CGImage
        let source: Source
    }

    private let memory = NSCache<NSString, IconBox>()
    private var inFlight: [String: Task<Icon?, Never>] = [:]
    private let directory = URL.cachesDirectory.appending(path: "casky/icons")
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        return URLSession(configuration: configuration)
    }()

    init() {
        memory.countLimit = 2000
    }

    /// - Parameter pixelSize: the drawn size in pixels (points × 2).
    func icon(for entry: CatalogEntry, pixelSize: Int) async -> Icon? {
        if case .formula = entry.item { return nil }
        // Looked up every time (cheap): an app installed a minute ago should
        // show its own icon right away.
        if let app = installedApp(entry) {
            return await cached("app:\(app.path):\(pixelSize)") {
                Self.thumbnail(of: NSWorkspace.shared.icon(forFile: app.path), pixelSize: pixelSize)
                    .map { Icon(image: $0, source: .installedApp) }
            }
        }
        return await cached("\(Self.key(entry.item)):\(pixelSize)") {
            guard let (data, source) = await self.data(for: entry) else { return nil }
            return Self.thumbnail(of: data, pixelSize: pixelSize).map { Icon(image: $0, source: source) }
        }
    }

    /// Memory cache plus de-duplication of concurrent requests for one key.
    private func cached(_ key: String, load: @escaping @Sendable () async -> Icon?) async -> Icon? {
        if let box = memory.object(forKey: key as NSString) { return box.icon }
        if let running = inFlight[key] { return await running.value }
        let task = Task { await load() }
        inFlight[key] = task
        let icon = await task.value
        inFlight[key] = nil
        memory.setObject(IconBox(icon), forKey: key as NSString)
        return icon
    }

    private func installedApp(_ entry: CatalogEntry) -> URL? {
        guard let bundle = entry.appBundleName else { return nil }
        return [URL(fileURLWithPath: "/Applications"), URL.homeDirectory.appending(path: "Applications")]
            .map { $0.appending(path: bundle) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Original image bytes, from the disk cache or downloaded.
    private func data(for entry: CatalogEntry) async -> (Data, Source)? {
        let file = directory.appending(path: Self.key(entry.item))
        let miss = file.appendingPathExtension("miss")
        let cachedSource: Source = entry.iconURL != nil ? .published : .website
        if let data = try? Data(contentsOf: file) { return (data, cachedSource) }
        if let date = (try? FileManager.default.attributesOfItem(atPath: miss.path))?[.modificationDate] as? Date,
           Date.now.timeIntervalSince(date) < 7 * 24 * 60 * 60 {
            return nil
        }

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (url, source) in await candidates(entry) {
            guard let data = await download(url), Self.thumbnail(of: data, pixelSize: 16) != nil else { continue }
            try? data.write(to: file, options: .atomic)
            return (data, source)
        }
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
        let declared = await download(homepage, limit: 2_000_000).map { WebPage.declared(in: $0, baseURL: homepage) } ?? []
        let conventional = ["apple-touch-icon.png", "favicon.ico"].compactMap { URL(string: "https://\(host)/\($0)") }
        return (declared + conventional).uniqued().map { ($0, .website) }
    }

    private func download(_ url: URL, limit: Int = 1_000_000) async -> Data? {
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              data.count < limit else { return nil }
        return data
    }

    /// Downscaled with ImageIO (PNG, JPEG, ICO, ...); other formats such as
    /// SVG go through NSImage.
    private static func thumbnail(of data: Data, pixelSize: Int) -> CGImage? {
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
               kCGImageSourceCreateThumbnailFromImageAlways: true,
               kCGImageSourceCreateThumbnailWithTransform: true,
               kCGImageSourceThumbnailMaxPixelSize: pixelSize,
           ] as CFDictionary) {
            return image
        }
        return NSImage(data: data).flatMap { thumbnail(of: $0, pixelSize: pixelSize) }
    }

    /// Picks the image representation closest to the size, as AppKit does
    /// when drawing an app icon.
    private static func thumbnail(of image: NSImage, pixelSize: Int) -> CGImage? {
        var rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
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
final class IconBox: @unchecked Sendable {
    let icon: IconStore.Icon?
    init(_ icon: IconStore.Icon?) { self.icon = icon }
}
