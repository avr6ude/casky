import Foundation

/// One command the runner executes.
struct InstallStep: Hashable, Sendable {
    enum Action: Hashable, Sendable {
        case tap(String)
        case install(Item)
    }

    let action: Action
    /// Earlier steps that must succeed; if any fails, the runner skips this one.
    let prerequisites: [Action]
}

/// Turns a selection into ordered steps. Pure: the caller supplies what is
/// installed and which items need admin rights.
///
/// Order: taps, formulae, casks, App Store apps. Within each group, items that
/// may prompt for a password go last so most of the work finishes unattended.
struct InstallPlan: Sendable {
    let steps: [InstallStep]
    /// Selected items skipped because they are already installed.
    let alreadyInstalled: [Item]

    /// - Parameter appBundles: the `.app` each selected app installs, so apps
    ///   already in an Applications folder are skipped too.
    init(selection: [Item], installed: InstalledState, appBundles: [Item: String] = [:], needsAdmin: Set<Item> = []) {
        let selection = selection.uniqued()
        let isPresent = { installed.isPresent($0, appBundle: appBundles[$0]) }
        let pending = selection.filter { !isPresent($0) }
        alreadyInstalled = selection.filter(isPresent)

        let tapsToAdd = pending.compactMap(\.tap).uniqued().filter { !installed.taps.contains($0) }
        let masTool = Item.formula(.masTool)
        let needsMasTool = pending.contains { if case .mas = $0 { true } else { false } }
            && !installed.contains(masTool)

        var formulae: [Item] = []
        var casks: [Item] = []
        var apps: [Item] = []
        for item in pending {
            switch item {
            case .formula: formulae.append(item)
            case .cask: casks.append(item)
            case .mas: apps.append(item)
            }
        }
        if needsMasTool, !formulae.contains(masTool) {
            formulae.insert(masTool, at: 0)
        }

        func adminLast(_ group: [Item]) -> [Item] {
            group.filter { !needsAdmin.contains($0) } + group.filter { needsAdmin.contains($0) }
        }

        func prerequisites(of item: Item) -> [InstallStep.Action] {
            var actions: [InstallStep.Action] = []
            if let tap = item.tap, tapsToAdd.contains(tap) { actions.append(.tap(tap)) }
            if case .mas = item, needsMasTool { actions.append(.install(masTool)) }
            return actions
        }

        steps = tapsToAdd.map { InstallStep(action: .tap($0), prerequisites: []) }
            + (adminLast(formulae) + adminLast(casks) + adminLast(apps)).map {
                InstallStep(action: .install($0), prerequisites: prerequisites(of: $0))
            }
    }
}
