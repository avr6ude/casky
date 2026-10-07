import Foundation

struct MacPreference: Codable, Hashable, Identifiable, Sendable {
    var domain: String
    var key: String
    /// nil removes the explicit override, returning to the system default.
    var value: MacPreferenceValue?
    var id: String { domain + "\u{0}" + key }
    var preset: Preset? { Self.presets.first { $0.id == id } }
    var title: String { preset?.title ?? key }
    /// Where the setting lives, for a row's subtitle.
    var subtitle: String { preset?.group ?? domain }

    /// How a value reads in the interface: the preset's option name when one
    /// matches, otherwise the plain value.
    func describe(_ value: MacPreferenceValue?) -> String {
        guard let value else { return "System Default" }
        if let option = preset?.options.first(where: { $0.value.isSame(as: value) }) { return option.title }
        switch value {
        case .boolean(let on): return on ? "On" : "Off"
        case .decimal(let number): return number.formatted()
        case .integer, .string: return value.text.isEmpty ? "Empty" : value.text
        }
    }

    func validated() throws -> Self {
        var result = self
        result.domain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        result.key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard !result.domain.isEmpty, result.domain.unicodeScalars.allSatisfy(allowed.contains),
              !result.domain.hasPrefix("-"), !result.key.isEmpty,
              !result.key.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw MacPreferencesError.invalid("Enter a preference domain, such as com.apple.finder, and a nonempty key.")
        }
        if case .decimal(let number) = value, !number.isFinite {
            throw MacPreferencesError.invalid("Preference numbers must be finite.")
        }
        return result
    }

    static func validated(_ preferences: [Self]) throws -> [Self] {
        let result = try preferences.map { try $0.validated() }
        guard Set(result.map(\.id)).count == result.count else {
            throw MacPreferencesError.invalid("Each domain and key can appear only once in a setup.")
        }
        return result
    }

    /// A well-known setting with the values System Settings offers for it.
    struct Preset: Identifiable, Sendable {
        struct Option: Hashable, Sendable {
            let title: String
            let value: MacPreferenceValue
            init(_ title: String, _ value: MacPreferenceValue) {
                self.title = title
                self.value = value
            }
        }

        let group: String
        let title: String
        let domain: String
        let key: String
        let options: [Option]
        var id: String { domain + "\u{0}" + key }

        static func onOff(_ group: String, _ title: String, _ domain: String, _ key: String) -> Self {
            .init(group: group, title: title, domain: domain, key: key, options: [.init("On", .boolean(true)), .init("Off", .boolean(false))])
        }
    }

    static let presets: [Preset] = [
        .onOff("Dock", "Automatically hide and show the Dock", "com.apple.dock", "autohide"),
        .init(group: "Dock", title: "Size", domain: "com.apple.dock", key: "tilesize", options: [
            .init("Small", .integer(32)), .init("Medium", .integer(48)), .init("Large", .integer(64)), .init("Extra Large", .integer(96)),
        ]),
        .onOff("Dock", "Magnification", "com.apple.dock", "magnification"),
        .onOff("Dock", "Show suggested and recent apps", "com.apple.dock", "show-recents"),
        .onOff("Finder", "Show hidden files", "com.apple.finder", "AppleShowAllFiles"),
        .onOff("Finder", "Show path bar", "com.apple.finder", "ShowPathbar"),
        .onOff("Finder", "Show status bar", "com.apple.finder", "ShowStatusBar"),
        .onOff("Finder", "Show all filename extensions", "NSGlobalDomain", "AppleShowAllExtensions"),
        // Values are the positions of the sliders in System Settings.
        .init(group: "Keyboard", title: "Key repeat rate", domain: "NSGlobalDomain", key: "KeyRepeat", options: [
            .init("Slowest", .integer(120)), .init("Slow", .integer(60)), .init("Medium", .integer(30)), .init("Fast", .integer(6)), .init("Fastest", .integer(2)),
        ]),
        .init(group: "Keyboard", title: "Delay until repeat", domain: "NSGlobalDomain", key: "InitialKeyRepeat", options: [
            .init("Longest", .integer(120)), .init("Long", .integer(68)), .init("Medium", .integer(35)), .init("Short", .integer(25)), .init("Shortest", .integer(15)),
        ]),
        .onOff("Keyboard", "Correct spelling automatically", "NSGlobalDomain", "NSAutomaticSpellingCorrectionEnabled"),
        .onOff("Keyboard", "Use smart quotes", "NSGlobalDomain", "NSAutomaticQuoteSubstitutionEnabled"),
        .onOff("Keyboard", "Use smart dashes", "NSGlobalDomain", "NSAutomaticDashSubstitutionEnabled"),
        .init(group: "Screenshots", title: "Format", domain: "com.apple.screencapture", key: "type", options: [
            .init("PNG", .string("png")), .init("JPEG", .string("jpg")), .init("HEIC", .string("heic")), .init("PDF", .string("pdf")), .init("TIFF", .string("tiff")),
        ]),
        .init(group: "Screenshots", title: "Window shadow", domain: "com.apple.screencapture", key: "disable-shadow", options: [
            .init("Include", .boolean(false)), .init("Leave Out", .boolean(true)),
        ]),
    ]
}

enum MacPreferenceValue: Codable, Hashable, Sendable {
    case boolean(Bool)
    case integer(Int)
    case decimal(Double)
    case string(String)

    enum Kind: String, CaseIterable, Identifiable, Sendable {
        case systemDefault = "System Default"
        case boolean = "Boolean"
        case integer = "Integer"
        case decimal = "Decimal"
        case string = "Text"
        var id: Self { self }
    }

    var kind: Kind {
        switch self {
        case .boolean: .boolean
        case .integer: .integer
        case .decimal: .decimal
        case .string: .string
        }
    }

    var text: String {
        switch self {
        case .boolean(let value): value ? "true" : "false"
        case .integer(let value): String(value)
        case .decimal(let value): String(value)
        case .string(let value): value
        }
    }

    /// Equal values, counting 48 and 48.0 as the same: macOS stores some
    /// whole numbers as decimals.
    func isSame(as other: Self) -> Bool {
        if let number, let otherNumber = other.number { return number == otherNumber }
        return self == other
    }

    private var number: Double? {
        switch self {
        case .integer(let value): Double(value)
        case .decimal(let value): value
        case .boolean, .string: nil
        }
    }

    static func parse(_ text: String, as kind: Kind) throws -> Self? {
        switch kind {
        case .systemDefault: return nil
        case .string: return .string(text)
        case .boolean:
            if text == "true" { return .boolean(true) }
            if text == "false" { return .boolean(false) }
        case .integer:
            if let value = Int(text) { return .integer(value) }
        case .decimal:
            if let value = Double(text), value.isFinite { return .decimal(value) }
        }
        throw MacPreferencesError.invalid("Enter a valid \(kind.rawValue.lowercased()) value.")
    }
}

enum MacPreferencesError: LocalizedError {
    case invalid(String)
    case changed(String)
    case write(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let message), .write(let message): message
        case .changed(let key): "\(key) changed since the preview. Close this preview and check again."
        }
    }
}
