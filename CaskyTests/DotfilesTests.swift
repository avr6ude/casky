import Foundation
import Testing
@testable import Casky

@Suite struct DotfilesTests {
    private struct Fixture {
        let root = FileManager.default.temporaryDirectory.appending(path: "casky-dotfiles-\(UUID().uuidString)")
        var source: URL { root.appending(path: "repository") }
        var home: URL { root.appending(path: "home") }
        var backups: URL { root.appending(path: "storage/backups") }
        var repository: DotfilesRepository {
            DotfilesRepository(directory: source, repository: "https://example.com/dotfiles.git", ref: "", paths: ["zshrc", "config", "config/editor.json"], submodules: [])
        }

        init() throws {
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            try write("export EDITOR=vim\n", to: source.appending(path: "zshrc"))
            try write("{\"theme\":\"system\"}", to: source.appending(path: "config/editor.json"))
        }

        func write(_ text: String, to url: URL) throws {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }

        func configuration(mode: Dotfile.Mode = .link) throws -> DotfilesConfiguration {
            DotfilesConfiguration(repository: repository.repository, files: [try Dotfile(source: "zshrc", destination: ".zshrc", mode: mode)])
        }

        func preview(_ configuration: DotfilesConfiguration) throws -> DotfilesPreview {
            try DotfilesRestore.preview(configuration, repository: repository, home: home, backups: backups)
        }
    }

    @Test func linksAndSkipsMatchingFilesOnSecondRestore() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let configuration = try fixture.configuration()
        let preview = try fixture.preview(configuration)
        #expect(preview.changes.first?.action == .create)
        #expect(!FileManager.default.fileExists(atPath: fixture.home.appending(path: ".zshrc").path))
        let result = try DotfilesRestore.apply(preview)
        #expect(result.restored == 1 && result.backupDirectory == nil)
        #expect(try String(contentsOf: fixture.home.appending(path: ".zshrc"), encoding: .utf8) == "export EDITOR=vim\n")
        let repeated = try fixture.preview(configuration)
        #expect(repeated.changedCount == 0)
        #expect(try DotfilesRestore.apply(repeated).unchanged == 1)
    }

    @Test func copiesFoldersAndBacksUpTheirWholeOriginalContents() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let destination = fixture.home.appending(path: ".config/editor")
        try fixture.write("original", to: destination.appending(path: "keep.txt"))
        let configuration = DotfilesConfiguration(repository: fixture.repository.repository, files: [
            try Dotfile(source: "config", destination: ".config/editor", mode: .copy),
        ])
        let preview = try fixture.preview(configuration)
        #expect(preview.changes.first?.action == .replace)
        let result = try DotfilesRestore.apply(preview)
        let backup = try #require(result.backupDirectory)
        #expect(try String(contentsOf: backup.appending(path: ".config/editor/keep.txt"), encoding: .utf8) == "original")
        #expect(!FileManager.default.fileExists(atPath: destination.appending(path: "keep.txt").path))
        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "editor.json").path))
        #expect(try fixture.preview(configuration).changedCount == 0)
        try fixture.write("new repository version", to: fixture.source.appending(path: "config/editor.json"))
        #expect(try String(contentsOf: destination.appending(path: "editor.json"), encoding: .utf8) == "{\"theme\":\"system\"}")
    }

    @Test func replacesDanglingLinkWithoutTouchingItsTarget() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let destination = fixture.home.appending(path: ".zshrc")
        let target = fixture.root.appending(path: "missing-target")
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: target)
        let result = try DotfilesRestore.apply(fixture.preview(fixture.configuration(mode: .copy)))
        let backup = try #require(result.backupDirectory).appending(path: ".zshrc")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: backup.path) == target.path)
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test func rejectsChangedDestinationsBeforeApplyingAnyEntry() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let destination = fixture.home.appending(path: ".zshrc")
        try fixture.write("original", to: destination)
        let configuration = DotfilesConfiguration(repository: fixture.repository.repository, files: [
            try Dotfile(source: "config", destination: ".config/editor", mode: .copy),
            try Dotfile(source: "zshrc", destination: ".zshrc", mode: .copy),
        ])
        let preview = try fixture.preview(configuration)
        try fixture.write("edited since preview", to: destination)
        #expect(throws: DotfilesError.self) { try DotfilesRestore.apply(preview) }
        #expect(try String(contentsOf: destination, encoding: .utf8) == "edited since preview")
        #expect(!FileManager.default.fileExists(atPath: fixture.home.appending(path: ".config").path))
        #expect(!FileManager.default.fileExists(atPath: preview.backupDirectory.path))
    }

    @Test func rejectsSourceEditsAndSourceLinks() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let configuration = try fixture.configuration()
        let preview = try fixture.preview(configuration)
        try fixture.write("new content", to: fixture.source.appending(path: "zshrc"))
        #expect(throws: DotfilesError.self) { try DotfilesRestore.apply(preview) }
        try FileManager.default.createSymbolicLink(at: fixture.source.appending(path: "config/outside"), withDestinationURL: fixture.home)
        let folder = DotfilesConfiguration(repository: fixture.repository.repository, files: [try Dotfile(source: "config", destination: ".config")])
        #expect(throws: DotfilesError.self) { try fixture.preview(folder) }
    }

    @Test func rejectsLinkedParentsIncludingOnesAddedAfterPreview() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let configuration = DotfilesConfiguration(repository: fixture.repository.repository, files: [
            try Dotfile(source: "config/editor.json", destination: ".config/editor.json", mode: .copy),
        ])
        let preview = try fixture.preview(configuration)
        let outside = fixture.root.appending(path: "outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: fixture.home.appending(path: ".config"), withDestinationURL: outside)
        #expect(throws: DotfilesError.self) { try fixture.preview(configuration) }
        #expect(throws: DotfilesError.self) { try DotfilesRestore.apply(preview) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
    }

    @Test func validatesDecodedPathsAndOverlappingDestinations() throws {
        for path in ["", "/etc/profile", "../escape", ".config/../escape", "~/.zshrc", "a//b", ".git/config", "a\n"] {
            #expect(throws: DotfilesError.self) { try DotfilePath(path) }
            let data = try JSONEncoder().encode(path)
            #expect(throws: (any Error).self) { try JSONDecoder().decode(DotfilePath.self, from: data) }
        }
        let configuration = DotfilesConfiguration(repository: "https://example.com/dotfiles.git", files: [
            try Dotfile(source: "config", destination: ".config"),
            try Dotfile(source: "editor", destination: ".CONFIG/editor"),
        ])
        #expect(throws: DotfilesError.self) { try configuration.validated() }
        for repository in ["", "--upload-pack=evil", "ext::evil", "http://example.com/repo", "https:///repo"] {
            #expect(throws: DotfilesError.self) { try DotfilesConfiguration(repository: repository, files: []).validated() }
        }
    }

    @Test func repositoryRefreshDoesNotMutateAnExistingLinkedCheckout() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let environment = ["PATH": "/usr/bin:/bin", "HOME": fixture.root.path, "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null"]
        func git(_ arguments: [String]) async throws {
            _ = try await ToolRunner.run(URL(fileURLWithPath: "/usr/bin/git"), arguments: ["-C", fixture.source.path] + arguments, environment: environment)
        }
        try await git(["init", "--initial-branch=main"])
        try await git(["add", "."])
        try await git(["-c", "user.name=Casky Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "initial"])
        let configuration = DotfilesConfiguration(repository: fixture.source.absoluteString, files: [try Dotfile(source: "zshrc", destination: ".zshrc")])
        let cache = fixture.root.appending(path: "storage/dotfiles")
        let first = try await DotfilesRepository.load(configuration, into: cache)
        #expect(first.paths.contains("config") && first.paths.contains("config/editor.json"))
        let preview = try DotfilesRestore.preview(configuration, repository: first, home: fixture.home, backups: fixture.backups)
        _ = try DotfilesRestore.apply(preview)
        let same = try await DotfilesRepository.load(configuration, into: cache)
        #expect(first.directory == same.directory)
        #expect(try DotfilesRestore.preview(configuration, repository: same, home: fixture.home, backups: fixture.backups).changedCount == 0)
        try fixture.write("local change", to: first.directory.appending(path: "zshrc"))
        let clean = try await DotfilesRepository.load(configuration, into: cache)
        #expect(clean.directory != first.directory)
        #expect(try String(contentsOf: fixture.home.appending(path: ".zshrc"), encoding: .utf8) == "local change")
        _ = try DotfilesRestore.apply(DotfilesRestore.preview(configuration, repository: clean, home: fixture.home, backups: fixture.backups))
        let repaired = try await DotfilesRepository.load(configuration, into: cache)
        #expect(repaired.directory == clean.directory)
        #expect(try DotfilesRestore.preview(configuration, repository: repaired, home: fixture.home, backups: fixture.backups).changedCount == 0)
        try fixture.write("updated", to: fixture.source.appending(path: "zshrc"))
        try await git(["add", "."])
        try await git(["-c", "user.name=Casky Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "update"])
        let second = try await DotfilesRepository.load(configuration, into: cache)
        #expect(first.directory != second.directory)
        #expect(try String(contentsOf: fixture.home.appending(path: ".zshrc"), encoding: .utf8) == "export EDITOR=vim\n")
        _ = try DotfilesRestore.apply(DotfilesRestore.preview(configuration, repository: second, home: fixture.home, backups: fixture.backups))
        #expect(try String(contentsOf: fixture.home.appending(path: ".zshrc"), encoding: .utf8) == "updated")
    }

    @Test func rejectsSubmodulesInsideSelectedFolders() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let repository = DotfilesRepository(directory: fixture.source, repository: fixture.repository.repository,
                                            ref: "", paths: ["config", "config/editor.json"], submodules: [try DotfilePath("config/plugins")])
        for source in ["config", "config/plugins", "config/plugins/file"] {
            let configuration = DotfilesConfiguration(repository: repository.repository, files: [try Dotfile(source: source, destination: ".config")])
            #expect(throws: DotfilesError.self) {
                try DotfilesRestore.preview(configuration, repository: repository, home: fixture.home, backups: fixture.backups)
            }
        }
        #expect(try String(contentsOf: fixture.source.appending(path: "config/editor.json"), encoding: .utf8) == "{\"theme\":\"system\"}")
    }

    @Test func stagingFailureLeavesOriginalInPlace() throws {
        let fixture = try Fixture()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fixture.home.path)
            try? FileManager.default.removeItem(at: fixture.root)
        }
        let destination = fixture.home.appending(path: ".zshrc")
        try fixture.write("original", to: destination)
        let preview = try fixture.preview(fixture.configuration(mode: .copy))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: fixture.home.path)
        #expect(throws: (any Error).self) { try DotfilesRestore.apply(preview) }
        #expect(try String(contentsOf: destination, encoding: .utf8) == "original")
        #expect(!FileManager.default.fileExists(atPath: preview.backupDirectory.path))
    }

    @Test func failedCloneCleansUpItsPartialCheckout() async throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let cache = fixture.root.appending(path: "storage/dotfiles")
        let configuration = DotfilesConfiguration(repository: fixture.root.appending(path: "missing-repository").absoluteString, files: [])
        await #expect(throws: ToolError.self) { try await DotfilesRepository.load(configuration, into: cache) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: cache.path).isEmpty)
    }
}

@MainActor @Suite struct DotfilesSetupTests {
    @Test func oldSetupsDecodeAndDotfilesConfigurationSurvivesRelaunch() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "casky-dotfiles-model-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let file = JSONFile<[SavedSetup]>(file: root.appending(path: "setups.json"))
        let old = Data(#"[{"id":"00000000-0000-0000-0000-000000000001","name":"Old","items":[],"createdAt":0}]"#.utf8)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try old.write(to: file.file)
        let defaults = UserDefaults(suiteName: "casky-dotfiles-tests-\(UUID().uuidString)")!
        func model() -> AppModel {
            AppModel(dataDirectory: root, defaults: defaults, locateHomebrew: { _ in nil }, applicationFolders: [], kits: [])
        }
        let first = model()
        let setup = try #require(first.setups.first)
        #expect(setup.dotfiles == nil)
        let configuration = DotfilesConfiguration(repository: "git@example.com:you/dotfiles.git", files: [try Dotfile(source: "zshrc", destination: ".zshrc")])
        try first.saveDotfiles(configuration, for: setup.id)
        #expect(model().setups.first?.dotfiles == configuration)
        try first.saveDotfiles(nil, for: setup.id)
        #expect(model().setups.first?.dotfiles == nil)
    }
}
