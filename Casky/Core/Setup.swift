import Foundation

/// A named selection and configuration the user saved.
struct SavedSetup: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var items: [Item]
    let createdAt: Date
    var dotfiles: DotfilesConfiguration? = nil
    var macPreferences: [MacPreference]? = nil
}
