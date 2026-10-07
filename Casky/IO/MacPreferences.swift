import CoreFoundation
import Foundation

/// Explicit current-user preferences for any host. Managed/system values and
/// per-host overrides are never copied or changed.
enum MacPreferences {
    struct Change: Codable, Identifiable, Sendable {
        let preference: MacPreference
        let before: MacPreferenceValue?
        let after: MacPreferenceValue?
        var id: String { preference.id }
        var isChanged: Bool { before != after }
    }

    struct Plan: Codable, Sendable {
        let changes: [Change]
        let date: Date
        var changedCount: Int { changes.filter(\.isChanged).count }
    }

    struct Applied: Sendable {
        let plan: Plan
        let backup: URL
    }

    static func capture(_ preferences: [MacPreference]) throws -> [MacPreference] {
        try MacPreference.validated(preferences).map { preference in
            var captured = preference
            captured.value = try read(preference)
            return captured
        }
    }

    static func preview(_ preferences: [MacPreference]) throws -> Plan {
        let changes = try MacPreference.validated(preferences).map { preference in
            Change(preference: preference, before: try read(preference), after: preference.value)
        }
        return Plan(changes: changes, date: .now)
    }

    static func apply(_ plan: Plan, backups: URL) throws -> Applied {
        try validate(plan)
        let backup = backups.appending(path: UUID().uuidString + ".json")
        try JSONFile<Plan>(file: backup).save(plan)
        for change in plan.changes where change.isChanged {
            guard try read(change.preference) == change.before else { throw MacPreferencesError.changed(change.preference.key) }
            try write(change.after, for: change.preference)
        }
        return Applied(plan: plan, backup: backup)
    }

    /// Entries untouched by a partial apply already match their originals.
    /// Refuse to overwrite values subsequently changed in another app.
    static func restorePreview(_ backup: Plan) throws -> Plan {
        _ = try MacPreference.validated(backup.changes.map(\.preference))
        let changes = try backup.changes.filter(\.isChanged).map { change in
            let current = try read(change.preference)
            guard current == change.before || current == change.after else { throw MacPreferencesError.changed(change.preference.key) }
            return Change(preference: change.preference, before: current, after: change.before)
        }
        return Plan(changes: changes, date: .now)
    }

    private static func validate(_ plan: Plan) throws {
        _ = try MacPreference.validated(plan.changes.map { change in
            var preference = change.preference
            preference.value = change.after
            return preference
        })
        for change in plan.changes {
            if change.isChanged, CFPreferencesAppValueIsForced(change.preference.key as CFString, domainID(change.preference.domain)) {
                throw MacPreferencesError.invalid("\(change.preference.key) is managed by your organization and can't be changed here.")
            }
            guard try read(change.preference) == change.before else { throw MacPreferencesError.changed(change.preference.key) }
        }
    }

    static func read(_ preference: MacPreference) throws -> MacPreferenceValue? {
        let domain = domainID(preference.domain)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw MacPreferencesError.write("Couldn't read \(preference.domain).")
        }
        guard let value = CFPreferencesCopyValue(preference.key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return nil }
        if CFGetTypeID(value) == CFBooleanGetTypeID(), let number = value as? NSNumber { return .boolean(number.boolValue) }
        if let text = value as? String { return .string(text) }
        if let number = value as? NSNumber {
            let kind = String(cString: number.objCType)
            if kind == "f" || kind == "d" {
                guard number.doubleValue.isFinite else { throw MacPreferencesError.invalid("\(preference.key) contains a nonfinite number.") }
                return .decimal(number.doubleValue)
            }
            guard let integer = Int(number.stringValue) else { throw MacPreferencesError.invalid("\(preference.key) is outside the supported integer range.") }
            return .integer(integer)
        }
        throw MacPreferencesError.invalid("\(preference.key) contains a complex value. Only Boolean, integer, decimal and text values are supported.")
    }

    private static func write(_ value: MacPreferenceValue?, for preference: MacPreference) throws {
        guard !CFPreferencesAppValueIsForced(preference.key as CFString, domainID(preference.domain)) else {
            throw MacPreferencesError.invalid("\(preference.key) is managed by your organization and can't be changed here.")
        }
        let object: CFPropertyList?
        switch value {
        case .boolean(let value): object = value ? kCFBooleanTrue : kCFBooleanFalse
        case .integer(let value): object = NSNumber(value: value)
        case .decimal(let value): object = NSNumber(value: value)
        case .string(let value): object = value as CFString
        case nil: object = nil
        }
        let domain = domainID(preference.domain)
        CFPreferencesSetValue(preference.key as CFString, object, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost), try read(preference) == value else {
            throw MacPreferencesError.write("Couldn't save \(preference.domain) / \(preference.key). Earlier changes may already have been applied; the backup keeps their original values.")
        }
    }

    private static func domainID(_ domain: String) -> CFString {
        domain == "NSGlobalDomain" ? kCFPreferencesAnyApplication : domain as CFString
    }

    /// Dock and Finder read their settings at launch, so changes to them
    /// show only after a restart.
    static func appsToRestart(for plan: Plan) -> [String] {
        let domains = Set(plan.changes.filter(\.isChanged).map(\.preference.domain))
        var apps: [String] = []
        if domains.contains("com.apple.dock") { apps.append("Dock") }
        if domains.contains("com.apple.finder") || plan.changes.contains(where: { $0.isChanged && $0.preference.key == "AppleShowAllExtensions" && $0.preference.domain == "NSGlobalDomain" }) { apps.append("Finder") }
        return apps
    }

    static func restartApps(for plan: Plan) async throws {
        let apps = appsToRestart(for: plan)
        // A process that wasn't running needs no restart; launch errors still surface.
        for app in apps {
            do { _ = try await ToolRunner.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: [app], environment: ["PATH": "/usr/bin:/bin"]) }
            catch ToolError.failed(_, let status, _) where status == 1 { }
        }
    }
}
