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

extension PackagePolicy.Rule {
    var title: String {
        switch self {
        case .keepUpdated: "Keep Updated"
        case .hold: "Hold Updates"
        case .remove: "Remove"
        }
    }
}

/// Offline, or just back: a strip across the top of the content.
struct ConnectionBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.connection {
        case .offline:
            strip("You're offline. Browsing uses what casky already has; installs, updates and App Store search wait until you're back.",
                  symbol: "wifi.slash", tint: .orange)
        case .backOnline:
            strip("Back online.", symbol: "wifi", tint: .green)
        case .online:
            EmptyView()
        }
    }

    private func strip(_ text: String, symbol: String, tint: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(tint.opacity(0.15))
            .overlay(alignment: .bottom) { Divider() }
            .transition(.move(edge: .top).combined(with: .opacity))
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
    static let update = Pill(text: "Update", symbol: "arrow.down", tint: .accentColor)
    static let held = Pill(text: "On hold", symbol: "pause.fill", tint: .orange)

    /// What installing an item that needs admin rights will do.
    static func approval(touchID: Bool) -> Pill {
        touchID ? Pill(text: "Asks for Touch ID", symbol: "touchid") : Pill(text: "Asks for password", symbol: "key.fill")
    }
}

extension AvailableUpdate {
    /// "4.44.3 → 4.94.0", without Homebrew's build suffix.
    var versions: String {
        "\(installed) → \(latest.split(separator: ",").first.map(String.init) ?? latest)"
    }
}
