import Foundation

/// A named selection and configuration the user saved.
struct SavedSetup: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var items: [Item]
    let createdAt: Date
    var dotfiles: DotfilesConfiguration? = nil
    var macPreferences: [MacPreference]? = nil
    /// How items differ from a plain install. Items without one are
    /// installed and otherwise left alone.
    var policies: [PackagePolicy]? = nil
    var extensions: [EditorExtension]? = nil

    func rule(for item: Item) -> PackagePolicy.Rule? {
        policies?.first { $0.item == item }?.rule
    }

    mutating func setRule(_ rule: PackagePolicy.Rule?, for item: Item) {
        var policies = (self.policies ?? []).filter { $0.item != item }
        if let rule { policies.append(PackagePolicy(item: item, rule: rule)) }
        self.policies = policies.isEmpty ? nil : policies
    }

    /// Swaps an item for another (`node` for `node@22`), keeping its place
    /// and its rule.
    mutating func replace(_ item: Item, with replacement: Item) {
        guard let index = items.firstIndex(of: item), !items.contains(replacement) else { return }
        let rule = rule(for: item)
        items[index] = replacement
        setRule(nil, for: item)
        setRule(rule, for: replacement)
    }

    /// The items this setup installs, as opposed to removes.
    var installs: [Item] { items.filter { rule(for: $0) != .remove } }
}

struct PackagePolicy: Codable, Hashable, Sendable {
    enum Rule: String, Codable, CaseIterable, Sendable {
        /// Upgrade whenever the setup is applied.
        case keepUpdated
        /// Never upgrade: `brew pin` for tools; casky's Updates leaves apps alone.
        case hold
        /// Uninstall if it's on the Mac.
        case remove
    }

    let item: Item
    var rule: Rule
}
