import Foundation
import ServiceManagement

/// The daily update agent (`Support/app.avrdude.Casky.updater.plist`, which
/// runs `Resources/update-agent`). Registered through SMAppService, so it
/// shows up in System Settings > General > Login Items and can be turned off
/// there too.
@MainActor
enum AutoUpdate {
    private static let service = SMAppService.agent(plistName: "app.avrdude.Casky.updater.plist")

    static var status: SMAppService.Status { service.status }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static let logURL = URL.homeDirectory.appending(path: "Library/Logs/casky/update.log")

    /// When the agent last ran, from its log file.
    static var lastRun: Date? {
        (try? FileManager.default.attributesOfItem(atPath: logURL.path))?[.modificationDate] as? Date
    }
}
