import Foundation

/// Portable configuration; repository checkouts and backups stay local.
struct DotfilesConfiguration: Codable, Hashable, Sendable {
    var repository: String
    var ref: String = ""
    var files: [Dotfile]

    func validated() throws -> Self {
        var result = self
        result.repository = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        result.ref = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: result.repository)
        let isURL = ["https", "ssh", "file"].contains(url?.scheme ?? "")
            && (url?.isFileURL == true || url?.host?.isEmpty == false)
        let isSSH = result.repository.hasPrefix("git@") && result.repository.contains(":")
        guard isURL || isSSH, !result.repository.contains(where: \.isNewline) else {
            throw DotfilesError.invalid("Enter an HTTPS or SSH Git URL, or choose a local repository.")
        }
        for (index, file) in files.enumerated() {
            for other in files.prefix(index) where file.destination.overlaps(other.destination) {
                throw DotfilesError.invalid("Destinations overlap: ~/\(file.destination.value) and ~/\(other.destination.value). Choose separate files or folders.")
            }
        }
        return result
    }
}

struct Dotfile: Codable, Hashable, Identifiable, Sendable {
    enum Mode: String, Codable, CaseIterable, Sendable {
        case link, copy
        var title: String { self == .link ? "Link" : "Copy" }
    }

    let id: UUID
    let source: DotfilePath
    var destination: DotfilePath
    var mode: Mode

    init(id: UUID = UUID(), source: String, destination: String, mode: Mode = .link) throws {
        self.id = id
        self.source = try DotfilePath(source)
        self.destination = try DotfilePath(destination)
        self.mode = mode
    }
}

/// Paths stay relative to the repository or home, including when decoded.
struct DotfilePath: Codable, Hashable, Sendable {
    let value: String

    init(_ value: String) throws {
        let segments = value.split(separator: "/", omittingEmptySubsequences: false)
        guard !value.isEmpty, !value.hasPrefix("~"),
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.lowercased() != ".git" }) else {
            throw DotfilesError.invalid("Use a relative path such as .zshrc or .config/nvim, without ~/, .. or .git.")
        }
        self.value = value
    }

    func overlaps(_ other: Self) -> Bool {
        let left = value.lowercased(), right = other.value.lowercased()
        return left == right || left.hasPrefix(right + "/") || right.hasPrefix(left + "/")
    }

    init(from decoder: Decoder) throws {
        try self.init(decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

enum DotfilesError: LocalizedError {
    case invalid(String)
    case changed(String)
    case restore(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message), .restore(let message): message
        case .changed(let path): "\(path) changed since the preview. Close the preview and check the changes again."
        }
    }
}
