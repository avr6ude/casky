import Foundation

/// Everything the preview shows beyond the catalog entry, decoded from
/// Homebrew's per-item API or Apple's lookup API.
struct AppDetails: Equatable, Sendable {
    struct Fact: Hashable, Sendable {
        let label: String
        let value: String
    }

    var facts: [Fact] = []
    /// Long description (App Store apps).
    var about: String?
    /// What Homebrew prints after installing, if anything.
    var caveats: String?
    var screenshots: [URL] = []
}

// MARK: - Decoding

extension AppDetails {
    /// `formulae.brew.sh/api/cask/<token>.json`
    static func fromCask(_ data: Data) throws -> AppDetails {
        let cask = try object(data)
        var details = AppDetails(caveats: nonEmpty(cask["caveats"] as? String))
        details.add("Version", cask["version"] as? String)
        if let autoUpdates = cask["auto_updates"] as? Bool {
            details.add("Updates", autoUpdates ? "Updates itself" : "With Homebrew")
        }
        details.add("Requires", macOSRequirement(cask["depends_on"]))
        details.add("Installs, last 30 days", installs(cask, kind: "install", period: "30d"))
        details.add("Installs, last year", installs(cask, kind: "install", period: "365d"))
        details.add("Downloads from", (cask["url"] as? String).flatMap { URL(string: $0)?.host() })
        return details
    }

    /// `formulae.brew.sh/api/formula/<name>.json`
    static func fromFormula(_ data: Data) throws -> AppDetails {
        let formula = try object(data)
        var details = AppDetails(caveats: nonEmpty(formula["caveats"] as? String))
        details.add("Version", (formula["versions"] as? [String: Any])?["stable"] as? String)
        details.add("License", formula["license"] as? String)
        let dependencies = formula["dependencies"] as? [String] ?? []
        details.add("Depends on", dependencies.isEmpty ? "Nothing else" : dependencies.joined(separator: ", "))
        details.add("Installs, last 30 days", installs(formula, kind: "install_on_request", period: "30d"))
        details.add("Installs, last year", installs(formula, kind: "install_on_request", period: "365d"))
        return details
    }

    /// `itunes.apple.com/lookup?id=<id>`
    static func fromAppStore(_ data: Data) throws -> AppDetails {
        guard let app = (try object(data)["results"] as? [[String: Any]])?.first else { throw DetailsError.notFound }
        var details = AppDetails(about: nonEmpty(app["description"] as? String))
        details.add("Price", app["formattedPrice"] as? String)
        if let rating = app["averageUserRating"] as? Double, let count = app["userRatingCount"] as? Int, count > 0 {
            details.add("Rating", "\(rating.formatted(.number.precision(.fractionLength(1)))) ★ (\(count.formatted()) ratings)")
        }
        details.add("Version", app["version"] as? String)
        details.add("Size", (app["fileSizeBytes"] as? String).flatMap(Int64.init).map { $0.formatted(.byteCount(style: .file)) })
        details.add("Requires", (app["minimumOsVersion"] as? String).map { "macOS \($0) or later" })
        details.add("Category", app["primaryGenreName"] as? String)
        details.add("Seller", app["sellerName"] as? String)
        details.screenshots = (app["screenshotUrls"] as? [String] ?? []).compactMap(URL.init(string:))
        return details
    }

    private mutating func add(_ label: String, _ value: String?) {
        guard let value, !value.isEmpty else { return }
        facts.append(Fact(label: label, value: value))
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw DetailsError.notFound }
        return object
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    /// `"depends_on": {"macos": {">=": ["14"]}}`
    private static func macOSRequirement(_ dependsOn: Any?) -> String? {
        guard let macOS = (dependsOn as? [String: Any])?["macos"] as? [String: [String]],
              let (comparison, versions) = macOS.first, let version = versions.first else { return nil }
        return comparison == ">=" ? "macOS \(version) or later" : "macOS \(comparison) \(version)"
    }

    /// Sum over variants (`ripgrep`, `ripgrep --HEAD`).
    private static func installs(_ item: [String: Any], kind: String, period: String) -> String? {
        guard let counts = ((item["analytics"] as? [String: Any])?[kind] as? [String: Any])?[period] as? [String: Int],
              !counts.isEmpty else { return nil }
        return counts.values.reduce(0, +).formatted()
    }
}

enum DetailsError: Error {
    case notFound
}
