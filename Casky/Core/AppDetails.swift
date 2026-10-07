import Foundation

/// Everything the preview shows beyond the catalog entry, decoded from
/// Homebrew's per-item API or Apple's lookup API.
struct AppDetails: Equatable, Sendable {
    struct Fact: Hashable, Sendable {
        let label: String
        let value: String
    }

    /// A titled group of label/value facts ("Overview", "Popularity").
    struct Section: Hashable, Sendable {
        let title: String
        var facts: [Fact]
    }

    /// A titled list of names or paths ("Installs", "Commands").
    struct Listing: Hashable, Sendable {
        let title: String
        let items: [String]
        /// Paths and commands read better in monospace.
        var isCode = false
    }

    var about: String?
    var whatsNew: String?
    /// What Homebrew prints after installing, if anything.
    var caveats: String?
    var screenshots: [URL] = []
    var sections: [Section] = []
    var listings: [Listing] = []
    /// The cask's download, for measuring its size.
    var downloadURL: URL?

    mutating func addSection(_ title: String, _ facts: [Fact?]) {
        let facts = facts.compactMap { $0 }
        if !facts.isEmpty { sections.append(Section(title: title, facts: facts)) }
    }

    mutating func addListing(_ title: String, _ items: [String], isCode: Bool = false) {
        if !items.isEmpty { listings.append(Listing(title: title, items: items, isCode: isCode)) }
    }
}

// MARK: - Homebrew casks

extension AppDetails {
    /// `formulae.brew.sh/api/cask/<token>.json`
    static func fromCask(_ data: Data) throws -> AppDetails {
        let cask = try object(data)
        let artifacts = cask["artifacts"] as? [[String: Any]] ?? []
        var details = AppDetails(caveats: nonEmpty(cask["caveats"] as? String))
        details.downloadURL = (cask["url"] as? String).flatMap(URL.init(string:))

        let dependsOn = cask["depends_on"] as? [String: Any] ?? [:]
        let conflicts = (cask["conflicts_with"] as? [String: Any])?["cask"] as? [String] ?? []
        let languages = cask["languages"] as? [String] ?? []
        let oldNames = cask["old_tokens"] as? [String] ?? []
        details.addSection("Overview", [
            fact("Version", cask["version"] as? String),
            fact("Updates", (cask["auto_updates"] as? Bool).map { $0 ? "Updates itself" : "Through Homebrew" }),
            fact("Installer", artifacts.contains { $0["pkg"] != nil || $0["installer"] != nil } ? "System installer, needs approval" : "Copies the app"),
            fact("Downloads from", details.downloadURL?.host()),
            fact("Languages", languages.isEmpty ? nil : "\(languages.count)"),
            fact("Formerly", oldNames.isEmpty ? nil : oldNames.joined(separator: ", ")),
            fact("Conflicts with", conflicts.isEmpty ? nil : conflicts.joined(separator: ", ")),
        ])
        let needs = ((dependsOn["formula"] as? [String] ?? []) + (dependsOn["cask"] as? [String] ?? []))
        details.addSection("Requirements", [
            fact("macOS", macOSRequirement(dependsOn["macos"]) ?? "Any supported version"),
            fact("Also installs", needs.isEmpty ? nil : needs.joined(separator: ", ")),
        ])
        details.addSection("Popularity", popularity(cask, kind: "install"))

        details.addListing("Installs", artifacts.flatMap(describeInstalled))
        details.addListing("Background services", artifacts.flatMap { uninstallValues($0["uninstall"], key: "launchctl") }, isCode: true)
        let cleanup = artifacts.flatMap { uninstallValues($0["zap"], key: "trash") + uninstallValues($0["zap"], key: "delete") + uninstallValues($0["zap"], key: "rmdir") }
        details.addListing("Uninstalling removes", cleanup, isCode: true)
        return details
    }

    /// One human-readable line per thing the cask puts on the Mac.
    private static func describeInstalled(_ artifact: [String: Any]) -> [String] {
        let kinds: [(key: String, label: String)] = [
            ("app", "App"), ("binary", "Command"), ("pkg", "Installer package"), ("font", "Font"),
            ("suite", "Folder in Applications"), ("qlplugin", "Quick Look plug-in"), ("prefpane", "System Settings pane"),
            ("screen_saver", "Screen saver"), ("service", "Service"), ("colorpicker", "Color picker"),
            ("dictionary", "Dictionary"), ("input_method", "Input method"), ("audio_unit_plugin", "Audio Unit plug-in"),
            ("vst_plugin", "VST plug-in"), ("vst3_plugin", "VST3 plug-in"), ("mdimporter", "Spotlight importer"),
            ("keyboard_layout", "Keyboard layout"), ("manpage", "Manual page"), ("internet_plugin", "Internet plug-in"),
        ]
        var lines: [String] = []
        for (key, label) in kinds {
            guard let values = artifact[key] as? [Any] else { continue }
            // ["Source.app", {"target": "Renamed.app"}]: the target is what lands on disk.
            let target = values.compactMap { ($0 as? [String: Any])?["target"] as? String }.first
            let source = values.compactMap { $0 as? String }.first
            if let name = (target ?? source).map({ ($0 as NSString).lastPathComponent }) {
                lines.append("\(label): \(name)")
            }
        }
        if artifact["installer"] != nil { lines.append("Runs the vendor's own installer") }
        return lines
    }

    /// Values of `key` inside `uninstall`/`zap` stanzas, which hold a string
    /// or a list of strings.
    private static func uninstallValues(_ stanza: Any?, key: String) -> [String] {
        (stanza as? [[String: Any]] ?? []).flatMap { entry -> [String] in
            if let one = entry[key] as? String { return [one] }
            return entry[key] as? [String] ?? []
        }
    }
}

// MARK: - Homebrew formulae

extension AppDetails {
    /// `formulae.brew.sh/api/formula/<name>.json`
    static func fromFormula(_ data: Data) throws -> AppDetails {
        let formula = try object(data)
        var details = AppDetails(caveats: nonEmpty(formula["caveats"] as? String))
        let bottles = ((formula["bottle"] as? [String: Any])?["stable"] as? [String: Any])?["files"] as? [String: Any] ?? [:]
        let prebuilt = bottles.keys.contains { $0.hasPrefix("arm64_") && $0 != "arm64_linux" }
        let aliases = formula["aliases"] as? [String] ?? []
        details.addSection("Overview", [
            fact("Version", (formula["versions"] as? [String: Any])?["stable"] as? String),
            fact("License", formula["license"] as? String),
            fact("Install", prebuilt ? "Prebuilt for Apple Silicon" : "Builds from source"),
            fact("Background service", formula["service"] is [String: Any] ? "Can run as a service (brew services)" : nil),
            fact("In your PATH", (formula["keg_only"] as? Bool) == true ? "No, kept separate (keg-only)" : "Yes"),
            fact("Also called", aliases.isEmpty ? nil : aliases.joined(separator: ", ")),
        ])
        details.addSection("Popularity", popularity(formula, kind: "install_on_request"))
        details.addListing("Commands", formula["executables"] as? [String] ?? [], isCode: true)
        details.addListing("Depends on", formula["dependencies"] as? [String] ?? [], isCode: true)
        details.addListing("Uses from macOS", (formula["uses_from_macos"] as? [Any] ?? []).compactMap { $0 as? String }, isCode: true)
        return details
    }
}

// MARK: - App Store

extension AppDetails {
    /// `itunes.apple.com/lookup?id=<id>`
    static func fromAppStore(_ data: Data) throws -> AppDetails {
        guard let app = (try object(data)["results"] as? [[String: Any]])?.first else { throw DetailsError.notFound }
        var details = AppDetails(about: nonEmpty(app["description"] as? String))
        details.whatsNew = nonEmpty(app["releaseNotes"] as? String)
        details.screenshots = (app["screenshotUrls"] as? [String] ?? []).compactMap(URL.init(string:))

        var rating: String?
        if let average = app["averageUserRating"] as? Double, let count = app["userRatingCount"] as? Int, count > 0 {
            rating = "\(average.formatted(.number.precision(.fractionLength(1)))) ★ from \(count.formatted()) ratings"
        }
        let languages = (app["languageCodesISO2A"] as? [String] ?? [])
            .map { Locale.current.localizedString(forLanguageCode: $0.lowercased()) ?? $0 }
        details.addSection("Overview", [
            fact("Price", app["formattedPrice"] as? String),
            fact("Rating", rating),
            fact("Version", app["version"] as? String),
            fact("Updated", date(app["currentVersionReleaseDate"])),
            fact("First released", date(app["releaseDate"])),
            fact("Size", (app["fileSizeBytes"] as? String).flatMap(Int64.init).map { $0.formatted(.byteCount(style: .file)) }),
            fact("Category", (app["genres"] as? [String])?.joined(separator: ", ")),
            fact("Age rating", app["trackContentRating"] as? String),
            fact("Seller", app["sellerName"] as? String),
        ])
        details.addSection("Requirements", [
            fact("macOS", (app["minimumOsVersion"] as? String).map { "\($0) or later" }),
            fact("Languages", languages.isEmpty ? nil : languages.count <= 4 ? languages.joined(separator: ", ") : "\(languages.count) languages"),
        ])
        return details
    }
}

// MARK: - Helpers

extension AppDetails {
    static func fact(_ label: String, _ value: String?) -> Fact? {
        guard let value, !value.isEmpty else { return nil }
        return Fact(label: label, value: value)
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw DetailsError.notFound }
        return object
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private static func date(_ value: Any?) -> String? {
        (value as? String).flatMap { try? Date($0, strategy: .iso8601) }?.formatted(date: .long, time: .omitted)
    }

    /// `"macos": {">=": ["14"]}`
    private static func macOSRequirement(_ macOS: Any?) -> String? {
        guard let macOS = macOS as? [String: [String]], let (comparison, versions) = macOS.first,
              let version = versions.first else { return nil }
        return comparison == ">=" ? "\(version) or later" : "\(comparison) \(version)"
    }

    /// Installs over 30 days, 90 days and a year, summed over variants
    /// (`ripgrep`, `ripgrep --HEAD`).
    private static func popularity(_ item: [String: Any], kind: String) -> [Fact?] {
        let counts = (item["analytics"] as? [String: Any])?[kind] as? [String: Any] ?? [:]
        return [("Last 30 days", "30d"), ("Last 90 days", "90d"), ("Last year", "365d")].map { label, period in
            let values = (counts[period] as? [String: Int])?.values
            return fact(label, values.map { "\($0.reduce(0, +).formatted()) installs" })
        }
    }
}

enum DetailsError: Error {
    case notFound
}
