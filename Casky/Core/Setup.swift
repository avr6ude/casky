import Foundation

/// A named selection the user saved.
struct SavedSetup: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var items: [Item]
    let createdAt: Date
}
