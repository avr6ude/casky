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

    func contains(_ item: Item) -> Bool {
        switch item {
        case .formula(let ref): formulae.contains(ref.fullName)
        case .cask(let ref): casks.contains(ref.fullName)
        case .mas(let id, _): masApps[id] != nil
        }
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
    ///   - masList: `mas list`, or nil when `mas` is not installed.
    static func decode(brewInfo: Data, tapInfo: Data, masList: String?) throws -> InstalledState {
        let info = try JSONDecoder().decode(BrewInfo.self, from: brewInfo)
        let taps = try JSONDecoder().decode([TapInfo].self, from: tapInfo)
        return InstalledState(
            formulae: Set(info.formulae.map { $0.full_name.lowercased() }),
            requestedFormulae: Set(info.formulae.filter { $0.installed.contains { $0.installed_on_request == true } }.map { $0.full_name.lowercased() }),
            casks: Set(info.casks.map { $0.full_token.lowercased() }),
            masApps: masList.map(parseMasList) ?? [:],
            taps: Set(taps.map { $0.name.lowercased() })
        )
    }

    /// `mas list` prints one app per line: `497799835  Xcode  (16.0)`.
    // ponytail: format taken from mas docs, not yet checked against a real
    // install (mas is not on the dev machine); revisit when the engine lands.
    static func parseMasList(_ output: String) -> [Int: String] {
        var apps: [Int: String] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let idText = trimmed.prefix { !$0.isWhitespace }
            guard let id = Int(idText) else { continue }
            var name = trimmed.dropFirst(idText.count).trimmingCharacters(in: .whitespaces)
            if name.hasSuffix(")"), let open = name.lastIndex(of: "(") {
                name = name[..<open].trimmingCharacters(in: .whitespaces)
            }
            apps[id] = name
        }
        return apps
    }

    private struct BrewInfo: Decodable {
        let formulae: [Formula]
        let casks: [Cask]
        struct Formula: Decodable {
            let full_name: String
            let installed: [Installed]
        }
        struct Installed: Decodable { let installed_on_request: Bool? }
        struct Cask: Decodable { let full_token: String }
    }

    private struct TapInfo: Decodable { let name: String }
}
