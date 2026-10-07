import Foundation

/// A newer version of something already on this Mac.
struct AvailableUpdate: Hashable, Sendable {
    let item: Item
    let installed: String
    let latest: String
    /// Homebrew manages it and upgrades it in place. Otherwise it's an app
    /// installed some other way, which Homebrew updates by replacing the
    /// copy in Applications (and manages from then on).
    let managed: Bool
    /// Pinned in Homebrew, or held by a setup: Update All leaves it alone.
    var isHeld = false
}

enum Updates {
    /// `brew outdated --greedy --json=v2`. Formulae are limited to `requested`
    /// ones: dependencies update along with what needs them.
    static func decodeOutdated(_ data: Data, requestedFormulae: Set<String>) throws -> [AvailableUpdate] {
        let outdated = try JSONDecoder().decode(Outdated.self, from: data)
        let formulae = outdated.formulae.compactMap { entry -> AvailableUpdate? in
            guard requestedFormulae.contains(entry.name.lowercased()), let ref = try? Ref(parsing: entry.name) else { return nil }
            return AvailableUpdate(item: .formula(ref), installed: entry.installed_versions.last ?? "", latest: entry.current_version, managed: true, isHeld: entry.pinned == true)
        }
        let casks = outdated.casks.compactMap { entry -> AvailableUpdate? in
            guard let ref = try? Ref(parsing: entry.name) else { return nil }
            return AvailableUpdate(item: .cask(ref), installed: entry.installed_versions.last ?? "", latest: entry.current_version, managed: true)
        }
        return formulae + casks
    }

    /// Whether `latest` is newer than `installed`. Homebrew writes cask
    /// versions as `4.94.0,241994` (version, build); apps as `4.94.0`, so the
    /// build part is ignored. Components compare numerically when both are
    /// numbers. "latest" and empty versions are never considered newer.
    static func isNewer(_ latest: String, than installed: String) -> Bool {
        let latestParts = components(latest), installedParts = components(installed)
        guard !latestParts.isEmpty, !installedParts.isEmpty, latest != "latest" else { return false }
        for index in 0..<max(latestParts.count, installedParts.count) {
            let new = index < latestParts.count ? latestParts[index] : "0"
            let old = index < installedParts.count ? installedParts[index] : "0"
            if let newNumber = Int(new), let oldNumber = Int(old) {
                if newNumber != oldNumber { return newNumber > oldNumber }
            } else if new != old {
                return new.compare(old, options: .numeric) == .orderedDescending
            }
        }
        return false
    }

    private static func components(_ version: String) -> [String] {
        (version.split(separator: ",").first.map(String.init) ?? "")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private struct Outdated: Decodable {
        let formulae: [Entry]
        let casks: [Entry]
        struct Entry: Decodable {
            let name: String
            let installed_versions: [String]
            let current_version: String
            let pinned: Bool?
        }
    }
}
