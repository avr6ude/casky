import Foundation

/// Something casky can install.
///
/// The kind is part of the identity: `docker` the cask and `docker` the formula
/// are different items.
enum Item: Hashable, Sendable {
    case formula(Ref)
    case cask(Ref)
    case mas(id: Int, name: String)

    enum Kind: Hashable, Sendable { case formula, cask, mas }

    var kind: Kind {
        switch self {
        case .formula: .formula
        case .cask: .cask
        case .mas: .mas
        }
    }

    /// The tap this item must come from, if any. Taps are never selected on
    /// their own; they are always derived from items.
    var tap: String? {
        switch self {
        case .formula(let ref), .cask(let ref): ref.tap
        case .mas: nil
        }
    }
}

/// Stored as `{"cask": "firefox"}`, `{"formula": "git"}` or
/// `{"mas": {"id": 497799835, "name": "Xcode"}}` so saved setups and the
/// bundled kits stay readable and hand-editable.
extension Item: Codable {
    private enum Key: String, CodingKey { case formula, cask, mas }
    private struct AppStoreApp: Codable { let id: Int; let name: String }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expected exactly one of formula, cask, mas"))
        }
        switch key {
        case .formula: self = .formula(try container.decode(Ref.self, forKey: key))
        case .cask: self = .cask(try container.decode(Ref.self, forKey: key))
        case .mas:
            let app = try container.decode(AppStoreApp.self, forKey: key)
            self = .mas(id: app.id, name: app.name)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .formula(let ref): try container.encode(ref, forKey: .formula)
        case .cask(let ref): try container.encode(ref, forKey: .cask)
        case .mas(let id, let name): try container.encode(AppStoreApp(id: id, name: name), forKey: .mas)
        }
    }
}

/// A Homebrew formula or cask name, optionally qualified by its tap.
///
/// Parsed and validated once at the input boundary (search results, Brewfile
/// import, saved setups); everything downstream, including process arguments,
/// trusts it.
struct Ref: Hashable, Sendable {
    /// Normalized `owner/repo`, never `homebrew/core` or `homebrew/cask`.
    let tap: String?
    let name: String

    /// The name Homebrew reports and accepts: `name` or `owner/repo/name`.
    var fullName: String { tap.map { "\($0)/\(name)" } ?? name }

    /// The `mas` CLI formula, installed on demand for App Store items.
    static let masTool = Ref(tap: nil, name: "mas")

    /// Accepts `name` or `owner/repo/name`, case-insensitively. A `homebrew-`
    /// repo prefix is dropped and the built-in taps collapse to plain names,
    /// matching how Homebrew itself reports them.
    init(parsing raw: String) throws(RefError) {
        let segments = raw.trimmingCharacters(in: .whitespaces).lowercased()
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        guard segments.allSatisfy(Self.isValidSegment) else { throw .invalid(raw) }

        switch segments.count {
        case 1:
            self.init(tap: nil, name: segments[0])
        case 3:
            let repo = segments[1].hasPrefix("homebrew-") ? String(segments[1].dropFirst(9)) : segments[1]
            guard Self.isValidSegment(repo) else { throw .invalid(raw) }
            let tap = "\(segments[0])/\(repo)"
            self.init(tap: Self.builtinTaps.contains(tap) ? nil : tap, name: segments[2])
        default:
            throw .invalid(raw)
        }
    }

    private init(tap: String?, name: String) {
        self.tap = tap
        self.name = name
    }

    private static let builtinTaps: Set<String> = ["homebrew/core", "homebrew/cask"]

    /// Characters Homebrew allows in tap, formula and cask names. Rejecting
    /// everything else also keeps names safe inside Brewfile string literals.
    private static func isValidSegment(_ segment: String) -> Bool {
        !segment.isEmpty && segment.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_.@+")
}

enum RefError: Error, Equatable {
    case invalid(String)
}

extension Ref: Codable {
    /// Stored as its full name so decoding goes through the same validation.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        try self.init(parsing: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(fullName)
    }
}
