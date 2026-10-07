import Foundation
import Testing
@testable import Casky

@Suite struct MacPreferencesTests {
    /// A throwaway domain so the tests never touch real settings.
    private let domain = "app.avrdude.casky.tests-\(UUID().uuidString)"
    private let backups = FileManager.default.temporaryDirectory.appending(path: "casky-preference-backups-\(UUID().uuidString)")

    @Test func applyThenUndoRestoresTheOriginal() throws {
        let preference = MacPreference(domain: domain, key: "Size", value: .integer(72))
        defer {
            CFPreferencesSetValue("Size" as CFString, nil, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            try? FileManager.default.removeItem(at: backups)
        }

        let plan = try MacPreferences.preview([preference])
        #expect(plan.changedCount == 1)
        let applied = try MacPreferences.apply(plan, backups: backups)
        #expect(try MacPreferences.read(preference) == .integer(72))
        #expect(FileManager.default.fileExists(atPath: applied.backup.path))
        #expect(try MacPreferences.preview([preference]).changedCount == 0)

        _ = try MacPreferences.apply(MacPreferences.restorePreview(applied.plan), backups: backups)
        #expect(try MacPreferences.read(preference) == nil)
    }

    @Test func undoRefusesValuesChangedElsewhere() throws {
        let preference = MacPreference(domain: domain, key: "Mode", value: .string("on"))
        defer {
            CFPreferencesSetValue("Mode" as CFString, nil, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            try? FileManager.default.removeItem(at: backups)
        }
        let applied = try MacPreferences.apply(MacPreferences.preview([preference]), backups: backups)
        CFPreferencesSetValue("Mode" as CFString, "other" as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        #expect(throws: MacPreferencesError.self) { try MacPreferences.restorePreview(applied.plan) }
    }

    @Test func dockAndFinderChangesAskForARestart() {
        let change = { (domain: String, key: String) in
            MacPreferences.Change(preference: .init(domain: domain, key: key, value: .boolean(true)), before: nil, after: .boolean(true))
        }
        let plan = MacPreferences.Plan(changes: [change("com.apple.dock", "autohide"), change("NSGlobalDomain", "AppleShowAllExtensions")], date: .now)
        #expect(MacPreferences.appsToRestart(for: plan) == ["Dock", "Finder"])
        #expect(MacPreferences.appsToRestart(for: .init(changes: [change("NSGlobalDomain", "KeyRepeat")], date: .now)).isEmpty)
    }

    @Test func presetsDescribeValuesByName() {
        let size = MacPreference(domain: "com.apple.dock", key: "tilesize", value: nil)
        #expect(size.describe(.decimal(48)) == "Medium")
        #expect(size.describe(.integer(39)) == "39")
        #expect(size.describe(nil) == "System Default")
        #expect(MacPreferenceValue.integer(48).isSame(as: .decimal(48)))
        #expect(!MacPreferenceValue.integer(48).isSame(as: .string("48")))
    }
}
