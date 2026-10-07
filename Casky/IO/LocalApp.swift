import Foundation

/// What an installed `.app` says about itself: its Info.plist, what it was
/// built for, who signed it, Gatekeeper's verdict and its size on disk.
enum LocalApp {
    static func location(of bundleName: String) -> URL? {
        [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/Applications/Utilities"), URL.homeDirectory.appending(path: "Applications")]
            .map { $0.appending(path: bundleName) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func facts(for app: URL) async -> [AppDetails.Fact] {
        let bundle = Bundle(url: app)
        let info = bundle?.infoDictionary ?? [:]
        let shortVersion = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String
        let version = [shortVersion, build.flatMap { $0 == shortVersion ? nil : "(\($0))" }].compactMap { $0 }.joined(separator: " ")

        async let signature = signature(of: app)
        async let gatekeeper = gatekeeper(of: app)
        async let size = Task.detached { sizeOnDisk(app) }.value

        return [
            AppDetails.fact("Version", version),
            AppDetails.fact("Location", (app.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath),
            AppDetails.fact("Size on disk", await size.map { $0.formatted(.byteCount(style: .file)) }),
            AppDetails.fact("Runs on", architectures(bundle?.executableArchitectures?.map(\.intValue) ?? [])),
            AppDetails.fact("Requires macOS", (info["LSMinimumSystemVersion"] as? String).map { "\($0) or later" }),
            AppDetails.fact("Bundle ID", bundle?.bundleIdentifier),
            AppDetails.fact("Signed by", await signature),
            AppDetails.fact("Gatekeeper", await gatekeeper),
        ].compactMap { $0 }
    }

    static func architectures(_ types: [Int]) -> String? {
        let arm = types.contains(NSBundleExecutableArchitectureARM64)
        let intel = types.contains(NSBundleExecutableArchitectureX86_64)
        switch (arm, intel) {
        case (true, true): return "Apple Silicon and Intel (Universal)"
        case (true, false): return "Apple Silicon"
        case (false, true): return "Intel only (runs with Rosetta)"
        default: return nil
        }
    }

    /// `codesign -dv` reports on stderr: the first `Authority=` line is the
    /// signing certificate, e.g. "Developer ID Application: Microsoft Corporation (UBF8T346G9)".
    static func signer(fromCodesign lines: [String]) -> String? {
        if let authority = lines.first(where: { $0.hasPrefix("Authority=") }) {
            return String(authority.dropFirst("Authority=".count))
        }
        return lines.contains { $0.hasPrefix("Signature=adhoc") } ? "Not signed by a developer (ad hoc)" : nil
    }

    /// `spctl -a -vv`: "accepted" plus `source=Notarized Developer ID`.
    static func gatekeeperVerdict(fromSpctl lines: [String]) -> String? {
        let source = lines.first { $0.hasPrefix("source=") }.map { String($0.dropFirst("source=".count)) }
        if lines.contains(where: { $0.hasSuffix(": accepted") }) { return source.map { "Allowed: \($0)" } ?? "Allowed" }
        if lines.contains(where: { $0.hasSuffix(": rejected") }) { return source.map { "Blocked: \($0)" } ?? "Blocked" }
        return nil
    }

    private static func signature(of app: URL) async -> String? {
        let lines = try? await ToolRunner.lines(URL(fileURLWithPath: "/usr/bin/codesign"), arguments: ["-dv", "--verbose=2", app.path])
        return lines.flatMap(signer(fromCodesign:))
    }

    private static func gatekeeper(of app: URL) async -> String? {
        let lines = try? await ToolRunner.lines(URL(fileURLWithPath: "/usr/sbin/spctl"), arguments: ["-a", "-vv", "-t", "execute", app.path])
        return lines.flatMap(gatekeeperVerdict(fromSpctl:))
    }

    private static func sizeOnDisk(_ app: URL) -> Int64? {
        guard let files = FileManager.default.enumerator(at: app, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else { return nil }
        var total: Int64 = 0
        for case let file as URL in files {
            total += Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
