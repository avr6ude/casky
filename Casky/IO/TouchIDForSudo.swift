import Foundation
import LocalAuthentication

/// Touch ID for admin prompts, via macOS's own mechanism: an
/// `auth sufficient pam_tid.so` line in /etc/pam.d/sudo_local (the file
/// /etc/pam.d/sudo includes, and which survives system updates). With it,
/// every `sudo` casky runs — and sudo in Terminal — shows the system Touch ID
/// prompt first; the password dialog stays as the fallback.
enum TouchIDForSudo {
    static let configFile = URL(fileURLWithPath: "/etc/pam.d/sudo_local")

    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    static var isEnabled: Bool {
        (try? String(contentsOf: configFile, encoding: .utf8)).map(isEnabled(in:)) ?? false
    }

    /// An uncommented `auth ... pam_tid.so` line.
    static func isEnabled(in config: String) -> Bool {
        config.split(whereSeparator: \.isNewline).contains { line in
            let fields = line.split(whereSeparator: \.isWhitespace)
            return fields.first == "auth" && fields.contains("pam_tid.so")
        }
    }

    /// The edit `setEnabled` runs as root. Turning on starts from Apple's
    /// template when there's no file yet and uncomments its line (or appends
    /// one); turning off comments it out. Anything else in the file is left
    /// alone. Separate so tests can run it on a copy.
    static func script(enabled: Bool, file: String) -> String {
        let line = "auth       sufficient     pam_tid.so"
        let active = "^[[:space:]]*auth[[:space:]].*pam_tid\\.so"
        let commented = "^[[:space:]]*#[[:space:]]*(auth[[:space:]].*pam_tid\\.so)"
        return enabled
            ? """
              if [ ! -f \(file) ] && [ -f \(file).template ]; then cp \(file).template \(file); fi; \
              if grep -Eq '\(commented)' \(file) 2>/dev/null; then sed -i '' -E 's/\(commented)/\\1/' \(file); \
              elif ! grep -Eq '\(active)' \(file) 2>/dev/null; then printf '%s\\n' '\(line)' >> \(file); fi
              """
            : "sed -i '' -E 's/(\(active))/#\\1/' \(file)"
    }

    /// Runs the edit through the standard macOS authorization dialog.
    static func setEnabled(_ enabled: Bool) async throws {
        let script = script(enabled: enabled, file: configFile.path)
        let prompt = enabled ? "casky wants to turn on Touch ID for admin prompts." : "casky wants to turn off Touch ID for admin prompts."
        _ = try await ToolRunner.run(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: [
                "-e", "on run argv",
                "-e", "do shell script (item 1 of argv) with administrator privileges with prompt (item 2 of argv)",
                "-e", "end run",
                script, prompt,
            ],
            environment: [:]
        )
    }
}
