import Foundation

/// What a product's homepage says about it: declared icons, share image and
/// description. HTML goes through Foundation's XMLDocument (tidy HTML).
enum WebPage {
    /// The page's own summary (`og:description`, else `description`).
    static func description(in html: Data) -> String? {
        guard let document = try? XMLDocument(data: html, options: [.documentTidyHTML]) else { return nil }
        for key in ["og:description", "description", "twitter:description"] {
            let path = "//meta[@property='\(key)' or @name='\(key)']/@content"
            if let content = (try? document.nodes(forXPath: path))?.first?.stringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
                return content
            }
        }
        return nil
    }

    /// The page's share image (`og:image`, else `twitter:image`), often a
    /// product screenshot.
    static func previewImage(in html: Data, baseURL: URL) -> URL? {
        guard let document = try? XMLDocument(data: html, options: [.documentTidyHTML]) else { return nil }
        for key in ["og:image", "twitter:image"] {
            let path = "//meta[@property='\(key)' or @name='\(key)']/@content"
            if let content = (try? document.nodes(forXPath: path))?.first?.stringValue,
               let url = URL(string: content, relativeTo: baseURL)?.absoluteURL, url.scheme == "https" {
                return url
            }
        }
        return nil
    }

    /// Icons the page declares with `<link rel="icon" | "apple-touch-icon">`,
    /// best first. Ranked by declared size (an apple-touch-icon without `sizes` counts as
    /// 180px, other undeclared sizes as 32px). Icons tied to a color scheme
    /// via `media` go last, since they may not suit the app's appearance.
    static func declared(in html: Data, baseURL: URL) -> [URL] {
        guard let document = try? XMLDocument(data: html, options: [.documentTidyHTML]),
              let links = try? document.nodes(forXPath: "//link[@rel][@href]") as? [XMLElement] else { return [] }
        let ranked = links.compactMap { link -> (url: URL, size: Int, themed: Bool)? in
            guard let rel = link.attribute(forName: "rel")?.stringValue?.lowercased(),
                  rel.split(separator: " ").contains(where: { $0 == "icon" || $0 == "apple-touch-icon" || $0 == "apple-touch-icon-precomposed" }),
                  let href = link.attribute(forName: "href")?.stringValue,
                  let url = URL(string: href, relativeTo: baseURL)?.absoluteURL,
                  url.scheme == "https" else { return nil }
            let declaredSize = link.attribute(forName: "sizes")?.stringValue?
                .split(separator: " ").compactMap { Int($0.split(separator: "x").first ?? "") }.max()
            let size = declaredSize ?? (rel.contains("apple-touch-icon") ? 180 : 32)
            return (url, size, link.attribute(forName: "media") != nil)
        }
        return ranked
            .sorted { ($0.themed ? 1 : 0, -$0.size) < ($1.themed ? 1 : 0, -$1.size) }
            .map(\.url)
            .uniqued()
    }
}
