import Foundation

/// What is already on this Mac, as reported by Homebrew and `mas`.
struct InstalledState: Sendable {
    /// Full names (`git`, `owner/repo/tool`).
    var formulae: Set<String> = []
    var casks: Set<String> = []
    var masApps: Set<Int> = []
    var taps: Set<String> = []

    func contains(_ item: Item) -> Bool {
        switch item {
        case .formula(let ref): formulae.contains(ref.fullName)
        case .cask(let ref): casks.contains(ref.fullName)
        case .mas(let id, _): masApps.contains(id)
        }
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
            casks: Set(info.casks.map { $0.full_token.lowercased() }),
            masApps: masList.map(parseMasList) ?? [],
            taps: Set(taps.map { $0.name.lowercased() })
        )
    }

    /// `mas list` prints one app per line: `497799835  Xcode  (16.0)`.
    // ponytail: format taken from mas docs, not yet checked against a real
    // install (mas is not on the dev machine); revisit when the engine lands.
    static func parseMasList(_ output: String) -> Set<Int> {
        Set(output.split(whereSeparator: \.isNewline).compactMap { line in
            line.split(whereSeparator: \.isWhitespace).first.flatMap { Int($0) }
        })
    }

    private struct BrewInfo: Decodable {
        let formulae: [Formula]
        let casks: [Cask]
        struct Formula: Decodable { let full_name: String }
        struct Cask: Decodable { let full_token: String }
    }

    private struct TapInfo: Decodable { let name: String }
}
