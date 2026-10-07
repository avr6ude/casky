import Foundation

/// The `.app` bundles in the Applications folders, however they were installed.
enum InstalledApps {
    static let defaultFolders = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/Applications/Utilities"),
        URL.homeDirectory.appending(path: "Applications"),
    ]

    /// Lowercased bundle names (`visual studio code.app`).
    static func bundleNames(in folders: [URL]) -> Set<String> {
        Set(folders.flatMap { folder in
            ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
                .filter { $0.hasSuffix(".app") }
                .map { $0.lowercased() }
        })
    }
}
