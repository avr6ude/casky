import CryptoKit
import Foundation

/// A preview freezes both sides. Applying rejects edits made after preview.
struct DotfilesPreview: Sendable {
    struct Change: Identifiable, Sendable {
        enum Action: Sendable { case create, replace, unchanged }
        let file: Dotfile
        let source: URL
        let destination: URL
        let sourceFingerprint: String
        let destinationFingerprint: String?
        let action: Action
        var id: UUID { file.id }
    }

    let changes: [Change]
    let home: URL
    let repositoryDirectory: URL
    let backupDirectory: URL
    var changedCount: Int { changes.filter { $0.action != .unchanged }.count }
}

struct DotfilesRestoreResult: Sendable {
    let restored: Int
    let unchanged: Int
    let backupDirectory: URL?
}

enum DotfilesRestore {
    static func preview(
        _ configuration: DotfilesConfiguration,
        repository: DotfilesRepository,
        home: URL = .homeDirectory,
        backups: URL
    ) throws -> DotfilesPreview {
        let configuration = try configuration.validated()
        guard configuration.repository == repository.repository, configuration.ref == repository.ref else {
            throw DotfilesError.invalid("Load the repository again after changing its URL or branch.")
        }
        let home = home.resolvingSymlinksInPath()
        let root = repository.directory.resolvingSymlinksInPath()
        let storage = backups.deletingLastPathComponent().resolvingSymlinksInPath()
        let changes = try configuration.files.map { file in
            if let submodule = repository.submodules.first(where: { file.source.overlaps($0) }) {
                throw DotfilesError.invalid("\(file.source.value) contains the Git submodule \(submodule.value), which isn't downloaded. Choose individual files outside it, or load that repository separately.")
            }
            let source = root.appending(path: file.source.value)
            let destination = home.appending(path: file.destination.value)
            guard !overlaps(destination, root), !overlaps(destination, storage) else {
                throw DotfilesError.invalid("~/\(file.destination.value) would replace Casky's repository or saved data. Choose another destination.")
            }
            try checkParents(of: source, inside: root)
            try checkParents(of: destination, inside: home)
            guard let sourceFingerprint = try fingerprint(source, allowsLinks: false) else {
                throw DotfilesError.invalid("\(file.source.value) isn't in this repository. Load it again or remove the entry.")
            }
            let destinationFingerprint = try fingerprint(destination)
            let matches: Bool
            if file.mode == .link, isLink(destination) {
                let target = try FileManager.default.destinationOfSymbolicLink(atPath: destination.path)
                let targetURL = URL(fileURLWithPath: target, relativeTo: destination.deletingLastPathComponent()).standardizedFileURL
                matches = targetURL == source.standardizedFileURL
            } else {
                matches = file.mode == .copy && destinationFingerprint == sourceFingerprint
            }
            return DotfilesPreview.Change(file: file, source: source, destination: destination,
                                          sourceFingerprint: sourceFingerprint, destinationFingerprint: destinationFingerprint,
                                          action: matches ? .unchanged : destinationFingerprint == nil ? .create : .replace)
        }
        return DotfilesPreview(changes: changes, home: home, repositoryDirectory: root,
                               backupDirectory: backups.appending(path: UUID().uuidString))
    }

    /// Each replacement is staged first, then backed up. If placing it fails,
    /// its original is restored; previously completed entries remain applied.
    static func apply(_ preview: DotfilesPreview) throws -> DotfilesRestoreResult {
        let manager = FileManager.default
        // Validate the whole preview before changing any destination.
        for change in preview.changes { try validate(change, preview: preview) }
        var restored = 0
        var hasBackups = false
        for change in preview.changes where change.action != .unchanged {
            try Task.checkCancellation()
            try validate(change, preview: preview)
            let parent = change.destination.deletingLastPathComponent()
            try manager.createDirectory(at: parent, withIntermediateDirectories: true)
            let staged = parent.appending(path: ".casky-stage-\(UUID().uuidString)")
            defer { try? manager.removeItem(at: staged) }
            switch change.file.mode {
            case .link:
                try manager.createSymbolicLink(at: staged, withDestinationURL: change.source)
            case .copy:
                try manager.copyItem(at: change.source, to: staged)
                guard try fingerprint(staged, allowsLinks: false) == change.sourceFingerprint else {
                    throw DotfilesError.changed(change.file.source.value)
                }
            }
            try validate(change, preview: preview)
            let backup = preview.backupDirectory.appending(path: change.file.destination.value)
            if change.action == .replace {
                try manager.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
                try manager.moveItem(at: change.destination, to: backup)
                hasBackups = true
            }
            do {
                try manager.moveItem(at: staged, to: change.destination)
            } catch {
                if change.action == .replace {
                    do {
                        try manager.moveItem(at: backup, to: change.destination)
                    } catch let recoveryError {
                        throw DotfilesError.restore("Couldn't restore ~/\(change.file.destination.value): \(error.localizedDescription). Its original is at \(backup.path). Moving it back also failed: \(recoveryError.localizedDescription)")
                    }
                }
                throw DotfilesError.restore("Couldn't restore ~/\(change.file.destination.value): \(error.localizedDescription). Earlier completed files remain restored. Backups are at \(preview.backupDirectory.path).")
            }
            restored += 1
        }
        return DotfilesRestoreResult(restored: restored, unchanged: preview.changes.count - restored,
                                     backupDirectory: hasBackups ? preview.backupDirectory : nil)
    }

    private static func validate(_ change: DotfilesPreview.Change, preview: DotfilesPreview) throws {
        try checkParents(of: change.source, inside: preview.repositoryDirectory)
        try checkParents(of: change.destination, inside: preview.home)
        guard try fingerprint(change.source, allowsLinks: false) == change.sourceFingerprint else {
            throw DotfilesError.changed(change.file.source.value)
        }
        guard try fingerprint(change.destination) == change.destinationFingerprint else {
            throw DotfilesError.changed("~/\(change.file.destination.value)")
        }
    }

    /// Reject symlinked ancestors, even dangling links. The leaf may be a link
    /// because replacing one backs up the link itself, never its target.
    private static func checkParents(of url: URL, inside root: URL) throws {
        guard let rootAttributes = try attributes(root), rootAttributes[.type] as? FileAttributeType == .typeDirectory else {
            throw DotfilesError.invalid("\(root.path) isn't a regular folder.")
        }
        var parent = url.deletingLastPathComponent()
        while parent.path != root.path {
            guard parent.path.hasPrefix(root.path + "/") else {
                throw DotfilesError.invalid("\(url.path) is outside its allowed folder.")
            }
            if let attributes = try attributes(parent), attributes[.type] as? FileAttributeType != .typeDirectory {
                throw DotfilesError.invalid("\(parent.path) isn't a regular folder. Choose a destination without linked folders in its path.")
            }
            parent.deleteLastPathComponent()
        }
    }

    private static func overlaps(_ left: URL, _ right: URL) -> Bool {
        let left = left.standardizedFileURL.path.lowercased(), right = right.standardizedFileURL.path.lowercased()
        return left == right || left.hasPrefix(right + "/") || right.hasPrefix(left + "/")
    }

    private static func isLink(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    private static func attributes(_ url: URL) throws -> [FileAttributeKey: Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: url.path)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return nil
        }
    }

    /// Hash contents, permissions, names and link targets without following
    /// links. Repository sources reject links and special files entirely.
    private static func fingerprint(_ url: URL, allowsLinks: Bool = true) throws -> String? {
        guard let attributes = try attributes(url) else { return nil }
        var hash = SHA256()
        func append(_ value: String) {
            let data = Data(value.utf8)
            hash.update(data: Data("\(data.count):".utf8))
            hash.update(data: data)
        }
        func visit(_ url: URL, name: String, attributes: [FileAttributeKey: Any]) throws {
            append(name)
            let type = attributes[.type] as? FileAttributeType
            append(type?.rawValue ?? "unknown")
            switch type {
            case .typeSymbolicLink:
                guard allowsLinks else {
                    throw DotfilesError.invalid("\(url.lastPathComponent) is a symbolic link inside the repository. Select its original file or folder instead.")
                }
                append(try FileManager.default.destinationOfSymbolicLink(atPath: url.path))
            case .typeRegular:
                append(String(describing: attributes[.posixPermissions] ?? ""))
                append(String(describing: attributes[.size] ?? ""))
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                while let data = try handle.read(upToCount: 64 * 1024), !data.isEmpty { hash.update(data: data) }
            case .typeDirectory:
                append(String(describing: attributes[.posixPermissions] ?? ""))
                let children = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent < $1.lastPathComponent }
                for child in children {
                    guard let attributes = try DotfilesRestore.attributes(child) else { throw DotfilesError.changed(child.path) }
                    try visit(child, name: child.lastPathComponent, attributes: attributes)
                }
            default:
                throw DotfilesError.invalid("\(url.path) isn't a regular file, folder or symbolic link.")
            }
        }
        try visit(url, name: "", attributes: attributes)
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
