import Foundation

/// One command the runner executes.
struct InstallStep: Hashable, Sendable {
    enum Action: Hashable, Sendable {
        case tap(String)
        case install(Item)
        /// Upgrade in place (Homebrew manages it).
        case update(Item)
        /// Have Homebrew replace a copy it doesn't manage with its newer one.
        case replace(Item)
        /// Uninstall something a setup removes.
        case remove(Item)
        /// Keep at its current version: `brew pin` for formulae; for apps,
        /// casky remembers and leaves them out of Update All.
        case hold(Item)
        case service(Ref, ServiceState)
        case editorExtension(EditorExtension)
        case globalPackage(GlobalPackage)
        /// Restore a setup's dotfiles from its repository.
        case dotfiles(setup: UUID, DotfilesConfiguration)
        /// Write a setup's Mac preferences.
        case preferences(setup: UUID, [MacPreference])

        /// Short name for messages: the tap, or the formula/cask/app name.
        var name: String {
            switch item {
            case .formula(let ref), .cask(let ref): ref.name
            case .mas(_, let name): name
            case nil:
                switch self {
                case .tap(let tap): tap
                case .service(let ref, _): ref.name
                case .editorExtension(let editorExtension): editorExtension.identifier
                case .globalPackage(let package): package.name
                case .dotfiles: "Dotfiles"
                case .preferences: "Mac preferences"
                case .install, .update, .replace, .remove, .hold: ""
                }
            }
        }

        var isUpdate: Bool {
            switch self {
            case .update, .replace: true
            case .tap, .install, .remove, .hold, .service, .editorExtension, .globalPackage, .dotfiles, .preferences: false
            }
        }

        var item: Item? {
            switch self {
            case .tap, .service, .editorExtension, .globalPackage, .dotfiles, .preferences: nil
            case .install(let item), .update(let item), .replace(let item), .remove(let item), .hold(let item): item
            }
        }
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

    init(steps: [InstallStep], alreadyInstalled: [Item]) {
        self.steps = steps
        self.alreadyInstalled = alreadyInstalled
    }

    /// Applying a saved setup: removals first (they may free up conflicts),
    /// then its packages (planned like any selection), updates and holds
    /// its policies ask for, then its dotfiles, then its Mac preferences,
    /// which may configure apps installed a moment earlier.
    ///
    /// - Parameters:
    ///   - packages: the plan for `setup.installs`.
    ///   - held: apps casky already holds back.
    init(setup: SavedSetup, packages: InstallPlan, installed: InstalledState = InstalledState(), updates: [Item: AvailableUpdate] = [:], held: Set<Item> = [],
         developer: DeveloperState = DeveloperState()) {
        var steps = setup.items
            .filter { setup.rule(for: $0) == .remove && installed.contains($0) }
            .map { InstallStep(action: .remove($0), prerequisites: []) }
        steps += packages.steps
        let installing = Set(packages.steps.map(\.action))
        for item in setup.items {
            switch setup.rule(for: item) {
            case .keepUpdated:
                guard let update = updates[item], !update.isHeld else { continue }
                steps.append(InstallStep(action: update.managed ? .update(item) : .replace(item), prerequisites: []))
            case .hold:
                let isHeld = if case .formula(let ref) = item { installed.pinned.contains(ref.fullName) } else { held.contains(item) }
                // A tool that isn't installed can't be pinned yet.
                let willInstall = installing.contains(.install(item))
                guard !isHeld, item.kind != .formula || installed.contains(item) || willInstall else { continue }
                steps.append(InstallStep(action: .hold(item), prerequisites: willInstall ? [.install(item)] : []))
            case .remove, nil:
                continue
            }
        }
        // Services of tools that are installed or about to be.
        for service in setup.services ?? [] where developer.services[service.formula.name] != service.state {
            let formula = Item.formula(service.formula)
            let willInstall = installing.contains(.install(formula))
            guard willInstall || installed.contains(formula) else { continue }
            steps.append(InstallStep(action: .service(service.formula, service.state), prerequisites: willInstall ? [.install(formula)] : []))
        }
        for editorExtension in setup.extensions ?? [] where developer.extensions[editorExtension.editor]?.contains(editorExtension.identifier) != true {
            let editor = InstallStep.Action.install(editorExtension.editor.cask)
            steps.append(InstallStep(action: .editorExtension(editorExtension), prerequisites: installing.contains(editor) ? [editor] : []))
        }
        for package in setup.packages ?? [] where developer.packages[package.manager]?.contains(package.name) != true {
            let manager = InstallStep.Action.install(package.manager.formula)
            steps.append(InstallStep(action: .globalPackage(package), prerequisites: installing.contains(manager) ? [manager] : []))
        }
        if let dotfiles = setup.dotfiles, !dotfiles.files.isEmpty {
            steps.append(InstallStep(action: .dotfiles(setup: setup.id, dotfiles), prerequisites: []))
        }
        if let preferences = setup.macPreferences, !preferences.isEmpty {
            steps.append(InstallStep(action: .preferences(setup: setup.id, preferences), prerequisites: []))
        }
        self.init(steps: steps, alreadyInstalled: packages.alreadyInstalled)
    }

    /// Updating: one step per update, App Store apps last (they may ask for
    /// the password). Taps and `mas` are already there.
    init(updates: [AvailableUpdate]) {
        let ordered = updates.filter { $0.item.kind != .mas } + updates.filter { $0.item.kind == .mas }
        steps = ordered.map { InstallStep(action: $0.managed ? .update($0.item) : .replace($0.item), prerequisites: []) }
        alreadyInstalled = []
    }

    /// - Parameter appBundles: the `.app` each selected app installs, so apps
    ///   already in an Applications folder are skipped too.
    /// - Parameter conflicts: casks each selected cask can't be installed
    ///   alongside; one of them being installed counts as installed.
    init(selection: [Item], installed: InstalledState, appBundles: [Item: String] = [:], conflicts: [Item: [Item]] = [:], needsAdmin: Set<Item> = []) {
        let selection = selection.uniqued()
        let isPresent = { installed.isPresent($0, appBundle: appBundles[$0], conflicts: conflicts[$0] ?? []) }
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
