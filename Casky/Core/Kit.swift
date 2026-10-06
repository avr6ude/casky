import Foundation

/// A curated starting selection, bundled as `kits.json`.
struct Kit: Codable, Hashable, Identifiable, Sendable {
    let slug: String
    /// SF Symbol name.
    let symbol: String
    let title: String
    let summary: String
    let items: [Item]

    var id: String { slug }
}
