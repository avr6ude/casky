import AppKit
import LocalAuthentication
import OpenDirectory
import Security

/// How installs that need admin rights get approved: with macOS's own
/// prompt (Touch ID, or the password on Macs without it), like anything
/// else in the system.
///
/// Homebrew and mas call `sudo` themselves, and `sudo` wants the password
/// text, which the system prompt never hands out. So casky asks for it
/// once, checks it, and keeps it in the login keychain; after that each
/// approval is the system prompt, and only then is the password passed to
/// `sudo` (through `SUDO_ASKPASS`, never on disk or in arguments).
enum AdminApproval {
    private static let service = "app.avrdude.casky.admin"

    static var hasTouchID: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: Keychain

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: NSUserName()]
    }

    static func storedPassword() -> String? {
        var query = query
        query[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var hasStoredPassword: Bool {
        var query = query
        query[kSecReturnAttributes as String] = true
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    static func store(_ password: String) {
        forget()
        var item = query
        item[kSecValueData as String] = Data(password.utf8)
        item[kSecAttrLabel as String] = "Casky admin approval"
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func forget() {
        SecItemDelete(query as CFDictionary)
    }

    // MARK: Checks

    /// Checks the password against the user's account without running
    /// anything that would show it in a process list.
    static func isCorrect(_ password: String) -> Bool {
        guard let node = try? ODNode(session: .default(), type: ODNodeType(kODNodeTypeAuthentication)),
              let record = try? node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: nil) else { return false }
        return (try? record.verifyPassword(password)) != nil
    }

    /// The system prompt: Touch ID, or the account password in the
    /// system's own sheet. `reason` completes "Casky is trying to …".
    static func approve(reason: String) -> Bool {
        let context = LAContext()
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var approved = false
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            approved = success
            done.signal()
        }
        done.wait()
        return approved
    }
}

/// `Casky --askpass`: what `sudo` runs (via the `askpass` script) when an
/// install needs admin rights. Prints the password for `sudo` and exits 0,
/// or exits 1 when the user cancels, which fails just that install.
@MainActor enum Askpass {
    static func run() -> Int32 {
        let item = ProcessInfo.processInfo.environment["CASKY_ASKPASS_ITEM"] ?? "this item"
        // sudo runs us again only when the password it got was wrong: the
        // saved one is out of date (the account password changed).
        let marker = FileManager.default.temporaryDirectory.appending(path: "casky-askpass-\(getppid())")
        let isRetry = FileManager.default.fileExists(atPath: marker.path)
        FileManager.default.createFile(atPath: marker.path, contents: nil)
        if isRetry { AdminApproval.forget() }

        if let password = AdminApproval.storedPassword() {
            guard AdminApproval.approve(reason: "install \(item)") else { return 1 }
            print(password)
            return 0
        }
        guard let password = askOnce(item: item, changed: isRetry) else { return 1 }
        AdminApproval.store(password)
        print(password)
        return 0
    }

    /// The one time casky needs the password itself.
    private static func askOnce(item: String, changed: Bool) -> String? {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.activate()
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        let alert = NSAlert()
        alert.messageText = changed ? "Your Mac password changed" : "Approve installs with \(AdminApproval.hasTouchID ? "Touch ID" : "your password")"
        alert.informativeText = """
            Enter your Mac password to install \(item). casky asks for it once and keeps it in your keychain; \
            after this, installs that need admin rights ask with the system prompt\(AdminApproval.hasTouchID ? ", using Touch ID" : "").
            """
        alert.accessoryView = field
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        while alert.runModal() == .alertFirstButtonReturn {
            if AdminApproval.isCorrect(field.stringValue) { return field.stringValue }
            alert.informativeText = "That isn't the password for \(NSUserName()). Try again."
            field.stringValue = ""
        }
        return nil
    }
}
