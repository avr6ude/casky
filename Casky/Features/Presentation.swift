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

/// A small status pill: "Installed", "Asks for Touch ID".
struct Pill: View {
    let text: String
    let symbol: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).imageScale(.small)
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: .capsule)
        .fixedSize()
    }

    static let installed = Pill(text: "Installed", symbol: "checkmark", tint: .green)

    /// What installing an item that needs admin rights will do.
    static func approval(touchID: Bool) -> Pill {
        touchID ? Pill(text: "Asks for Touch ID", symbol: "touchid") : Pill(text: "Asks for password", symbol: "key.fill")
    }
}
