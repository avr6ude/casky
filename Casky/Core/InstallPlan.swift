import Foundation

/// What is already on this Mac, as reported by `brew info --installed` and `mas list`.
struct InstalledState: Sendable {
    /// Full names (`git`, `owner/repo/tool`).
    var formulae: Set<String> = []
    var casks: Set<String> = []
    var masApps: Set<Int> = []
    var taps: Set<String> = []

    func contains(_ item: Item) -> Bool {
        switch item {
        case .formula(let ref): formulae.contains(ref.fullName)
        case .cask(let ref): casks.contains(ref.fullName)
        case .mas(let id, _): masApps.contains(id)
        }
    }
}

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

    init(selection: [Item], installed: InstalledState, needsAdmin: Set<Item> = []) {
        let selection = selection.uniqued()
        let pending = selection.filter { !installed.contains($0) }
        alreadyInstalled = selection.filter { installed.contains($0) }

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
