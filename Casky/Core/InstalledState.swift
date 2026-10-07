import Foundation

/// What is already on this Mac, as reported by Homebrew and `mas`.
struct InstalledState: Sendable {
    /// Full names (`git`, `owner/repo/tool`), including dependencies.
    var formulae: Set<String> = []
    /// The formulae the user asked for, as opposed to their dependencies.
    var requestedFormulae: Set<String> = []
    var casks: Set<String> = []
    /// App Store id → name.
    var masApps: [Int: String] = [:]
    var taps: Set<String> = []
    /// Formulae held back with `brew pin`.
    var pinned: Set<String> = []
    /// Lowercased names of the `.app` bundles in the Applications folders,
    /// however they got there.
    var appBundles: Set<String> = []

    /// Installed through Homebrew or `mas`.
    func contains(_ item: Item) -> Bool {
        switch item {
        case .formula(let ref): formulae.contains(ref.fullName)
        case .cask(let ref): casks.contains(ref.fullName)
        case .mas(let id, _): masApps[id] != nil
        }
    }

    /// Installed through Homebrew or `mas`, or, for apps, present in an
    /// Applications folder: a drag-installed VS Code counts, and Homebrew
    /// would refuse to install over it anyway.
    func isPresent(_ item: Item, appBundle: String?) -> Bool {
        if contains(item) { return true }
        guard let appBundle else { return false }
        return appBundles.contains(appBundle.lowercased())
    }

    /// Everything the user installed on purpose, for "Save this Mac as a
    /// setup": requested formulae, all casks, all App Store apps.
    func snapshot() -> [Item] {
        let formulae = requestedFormulae.sorted().compactMap { try? Ref(parsing: $0) }.map(Item.formula)
        let casks = casks.sorted().compactMap { try? Ref(parsing: $0) }.map(Item.cask)
        let apps = masApps.sorted { $0.value.localizedStandardCompare($1.value) == .orderedAscending }
            .map { Item.mas(id: $0.key, name: $0.value) }
        return formulae + casks + apps
    }
}

extension InstalledState {
    /// - Parameters:
    ///   - brewInfo: `brew info --json=v2 --installed`
    ///   - tapInfo: `brew tap-info --json --installed`
    ///   - masList: `mas list --json`, or nil when `mas` is not installed.
    static func decode(brewInfo: Data, tapInfo: Data, masList: Data?) throws -> InstalledState {
        let info = try JSONDecoder().decode(BrewInfo.self, from: brewInfo)
        let taps = try JSONDecoder().decode([TapInfo].self, from: tapInfo)
        return InstalledState(
            formulae: Set(info.formulae.map { $0.full_name.lowercased() }),
            requestedFormulae: Set(info.formulae.filter { $0.installed.contains { $0.installed_on_request == true } }.map { $0.full_name.lowercased() }),
            casks: Set(info.casks.map { $0.full_token.lowercased() }),
            masApps: try masList.map(parseMasList) ?? [:],
            taps: Set(taps.map { $0.name.lowercased() }),
            pinned: Set(info.formulae.filter { $0.pinned == true }.map { $0.full_name.lowercased() })
        )
    }

    /// `mas list --json`: a stream of JSON objects, one per app, with
    /// `adamID` and `name` among many Spotlight-derived keys.
    static func parseMasList(_ output: Data) throws -> [Int: String] {
        var apps: [Int: String] = [:]
        for object in try JSONStream.objects(in: output) {
            guard let app = try JSONSerialization.jsonObject(with: object) as? [String: Any],
                  let name = app["name"] as? String else { continue }
            let id = (app["adamID"] as? Int) ?? (app["adamID"] as? String).flatMap { Int($0) }
            if let id, id != 0 { apps[id] = name }
        }
        return apps
    }

    private struct BrewInfo: Decodable {
        let formulae: [Formula]
        let casks: [Cask]
        struct Formula: Decodable {
            let full_name: String
            let installed: [Installed]
            let pinned: Bool?
        }
        struct Installed: Decodable { let installed_on_request: Bool? }
        struct Cask: Decodable { let full_token: String }
    }

    private struct TapInfo: Decodable { let name: String }
}

/// Splits concatenated top-level JSON objects (`{...}{...}` or one per line)
/// so each can go through `JSONSerialization`. Only finds boundaries; the
/// objects themselves are parsed by Foundation.
enum JSONStream {
    struct Malformed: Error {}

    static func objects(in data: Data) throws -> [Data] {
        var objects: [Data] = []
        var depth = 0, start = 0
        var inString = false, escaped = false
        for (offset, byte) in data.enumerated() {
            if inString {
                if escaped { escaped = false }
                else if byte == UInt8(ascii: "\\") { escaped = true }
                else if byte == UInt8(ascii: "\"") { inString = false }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""): inString = true
            case UInt8(ascii: "{"):
                if depth == 0 { start = offset }
                depth += 1
            case UInt8(ascii: "}"):
                depth -= 1
                guard depth >= 0 else { throw Malformed() }
                if depth == 0 { objects.append(data.subdata(in: start..<offset + 1)) }
            default: break
            }
        }
        guard depth == 0, !inString else { throw Malformed() }
        return objects
    }
}
