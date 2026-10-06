import SwiftUI

/// User-facing names and symbols for item kinds, kept in one place so every
/// screen says "App", never "cask".
extension Item.Kind {
    var label: String {
        switch self {
        case .cask: "App"
        case .formula: "Command-line tool"
        case .mas: "App Store"
        }
    }

    var pluralLabel: String {
        switch self {
        case .cask: "Apps"
        case .formula: "Command-line tools"
        case .mas: "App Store"
        }
    }

    var symbol: String {
        switch self {
        case .cask: "macwindow"
        case .formula: "terminal"
        case .mas: "bag"
        }
    }
}

extension Item {
    /// The identifier Homebrew or the App Store uses, for detail rows.
    var technicalName: String {
        switch self {
        case .formula(let ref), .cask(let ref): ref.fullName
        case .mas(let id, _): "id \(id)"
        }
    }
}
