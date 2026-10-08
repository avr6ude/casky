import Foundation

/// A whole setup as one file to move to another Mac: packages and their
/// rules, services, editor extensions, global packages, dotfiles and Mac
/// preferences. What only makes sense on this Mac (backups, checkouts,
/// history) stays behind. A Brewfile carries packages only.
///
/// Reading one validates everything the way casky's own setups are, since
/// the file may come from anyone.
struct SetupFile: Codable {
    static let format = "casky-setup"
    static let version = 1

    let format: String
    let version: Int
    let name: String
    let items: [Item]
    var policies: [PackagePolicy]?
    var services: [ServicePolicy]?
    var extensions: [EditorExtension]?
    var packages: [GlobalPackage]?
    var dotfiles: DotfilesConfiguration?
    var macPreferences: [MacPreference]?

    init(_ setup: SavedSetup) {
        format = Self.format
        version = Self.version
        name = setup.name
        items = setup.items
        policies = setup.policies
        services = setup.services
        extensions = setup.extensions
        packages = setup.packages
        dotfiles = setup.dotfiles
        macPreferences = setup.macPreferences
    }

    static func encode(_ setup: SavedSetup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(SetupFile(setup))
    }

    /// A new saved setup (new ID, created now) from a file's contents.
    static func decode(_ data: Data, now: Date = .now) throws -> SavedSetup {
        let file: SetupFile
        do {
            file = try JSONDecoder().decode(SetupFile.self, from: data)
        } catch {
            throw SetupFileError.unreadable
        }
        guard file.format == format else { throw SetupFileError.unreadable }
        guard file.version <= version else { throw SetupFileError.newer }
        let name = file.name.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let items = file.items.uniqued()
        return SavedSetup(
            id: UUID(),
            name: name.isEmpty ? "Imported setup" : String(name.prefix(100)),
            items: items,
            createdAt: now,
            dotfiles: try file.dotfiles?.validated(),
            macPreferences: try file.macPreferences.map(MacPreference.validated),
            policies: file.policies.map { policies in policies.filter { items.contains($0.item) } },
            extensions: file.extensions?.uniqued(),
            services: file.services,
            packages: file.packages?.uniqued()
        )
    }
}

enum SetupFileError: LocalizedError, Equatable {
    case unreadable
    case newer

    var errorDescription: String? {
        switch self {
        case .unreadable: "This isn't a Casky setup file, or it's damaged."
        case .newer: "This setup was saved by a newer version of Casky. Update Casky to open it."
        }
    }
}
