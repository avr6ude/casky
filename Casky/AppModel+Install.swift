import AppKit

extension AppModel {
    /// What installing `items` (the selection by default) would do right now.
    func previewPlan(for items: [Item]? = nil) -> InstallPlan {
        let selection = items ?? selection
        let bundles = selection.compactMap { item in entry(for: item)?.appBundleName.map { (item, $0) } }
        let conflicts = selection.compactMap { item in entry(for: item)?.conflicts.map { (item, $0) } }
        return InstallPlan(
            selection: selection, installed: installed,
            appBundles: Dictionary(bundles, uniquingKeysWith: { first, _ in first }),
            conflicts: Dictionary(conflicts, uniquingKeysWith: { first, _ in first }),
            needsAdmin: catalog?.adminItems ?? []
        )
    }

    enum RunKind: Sendable {
        case install([Item])
        case update([Item])
        case setup(SavedSetup.ID)
    }

    /// What applying a saved setup would do right now.
    func previewPlan(for setup: SavedSetup) -> InstallPlan {
        InstallPlan(setup: setup, packages: previewPlan(for: setup.installs), installed: installed, updates: updates, held: heldItems, developer: developerState)
    }

    /// One line per step, for the run window, the review sheet and history.
    func title(for action: InstallStep.Action) -> String {
        switch action {
        case .tap(let tap): "Add tap \(tap)"
        case .install(let item): displayEntry(for: item).title
        case .update(let item), .replace(let item): "Update \(displayEntry(for: item).title)"
        case .remove(let item): "Remove \(displayEntry(for: item).title)"
        case .hold(let item): "Hold \(displayEntry(for: item).title) at its version"
        case .service(let ref, let state): "\(ref.name) service: \(state.title.lowercased())"
        case .editorExtension(let editorExtension): "\(editorExtension.editor.title) extension \(editorExtension.identifier)"
        case .globalPackage(let package): "\(package.name) with \(package.manager.title)"
        case .dotfiles(_, let configuration): configuration.files.count == 1 ? "Restore 1 dotfile" : "Restore \(configuration.files.count) dotfiles"
        case .preferences(_, let preferences): preferences.count == 1 ? "Apply 1 Mac setting" : "Apply \(preferences.count) Mac settings"
        }
    }

    var isSetupRun: Bool {
        if case .setup = lastRun { true } else { false }
    }

    /// Installs a setup's packages, restores its dotfiles and applies its
    /// Mac preferences, in one run.
    func apply(_ setup: SavedSetup) async {
        await perform(.setup(setup.id))
    }

    var isUpdateRun: Bool {
        if case .update = lastRun { true } else { false }
    }

    /// Installs `items` (the selection by default) one step at a time.
    func install(_ items: [Item]? = nil) async {
        await perform(.install(items ?? selection))
    }

    /// Updates `items` that have an update available.
    func update(_ items: [Item]) async {
        await perform(.update(items))
    }

    /// Runs the last install or update again; whatever finished last time
    /// is installed or current now and drops out.
    func retryLastRun() async {
        if let lastRun { await perform(lastRun) }
    }

    private func perform(_ kind: RunKind) async {
        // A setup can also restore dotfiles and preferences without Homebrew;
        // its package steps then fail and say why.
        guard !isInstalling, homebrew != nil || { if case .setup = kind { true } else { false } }() else { return }
        isInstalling = true
        defer { isInstalling = false }

        lastRun = kind
        runNote = nil
        currentOutput = []
        // Show the progress window right away: updating Homebrew first can
        // take a while.
        run = RunState(plan: InstallPlan(steps: [], alreadyInstalled: []))
        isPreparing = true
        do {
            _ = try await homebrew?.run(["update"])
        } catch {
            // Not fatal: Homebrew works with the package data it already has.
            runNote = "Couldn't update Homebrew first: \(Self.describe(error))"
        }
        await refreshInstalled()
        isPreparing = false
        switch kind {
        case .install(let items):
            run = RunState(plan: previewPlan(for: items))
        case .update(let items):
            await refreshUpdates()
            run = RunState(plan: InstallPlan(updates: items.compactMap { updates[$0] }))
        case .setup(let id):
            // The saved version, so Retry picks up edits made in between.
            guard let setup = setups.first(where: { $0.id == id }) else {
                run = nil
                return
            }
            if setup.policies?.contains(where: { $0.rule == .keepUpdated }) == true { await refreshUpdates() }
            await refreshDeveloperState()
            run = RunState(plan: previewPlan(for: setup))
        }

        while let step = run?.nextStep() {
            currentOutput = []
            currentStepStarted = .now
            // Await first: `run` may change (Stop) while the step runs.
            let outcome = await execute(step, with: homebrew)
            run?.finish(outcome, log: step.action.item == nil ? currentOutput : [])
        }
        currentStepStarted = nil
        if let run { record(run) }
        // The run window stays up with the result; get attention if the
        // user switched away during a long install.
        if !NSApp.isActive { NSApp.requestUserAttention(.informationalRequest) }
        // The run is over for the user; refreshing what's installed can
        // take a few seconds and shouldn't keep the sheet on "Installing…".
        isInstalling = false
        await refreshInstalled()
        await refreshUpdates()
    }

    func refreshDeveloperState() async {
        developerState = await DeveloperTools.state(homebrew: homebrew)
    }

    func stopAfterCurrentStep() {
        run?.requestStop()
    }

    func dismissRun() {
        guard !isInstalling else { return }
        run = nil
        currentOutput = []
    }

    private func execute(_ step: InstallStep, with homebrew: Homebrew?) async -> RunState.Outcome {
        let (lines, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1000))
        if case .hold(let item) = step.action, item.kind != .formula {
            setHeld(item, true)
            currentOutput = ["casky leaves \(displayEntry(for: item).title) out of Update All from now on."]
            return .installed
        }
        let checkouts = dotfilesDirectory, dotfileBackups = dotfilesBackupsDirectory, preferenceBackups = preferencesBackupsDirectory
        let task = Task.detached { () async throws -> Int32 in
            defer { continuation.finish() }
            let onLine: @Sendable (String) -> Void = { continuation.yield($0) }
            switch step.action {
            case .dotfiles(let id, let configuration):
                try await SetupSteps.restoreDotfiles(configuration, checkouts: checkouts.appending(path: id.uuidString), backups: dotfileBackups, onLine: onLine)
                return 0
            case .editorExtension(let editorExtension):
                return try await DeveloperTools.install(editorExtension, onLine: onLine)
            case .globalPackage(let package):
                return try await DeveloperTools.install(package, onLine: onLine)
            case .preferences(let id, let preferences):
                try await SetupSteps.applyPreferences(preferences, backups: preferenceBackups.appending(path: id.uuidString), onLine: onLine)
                return 0
            default:
                guard let homebrew else { throw ToolError.missing("Homebrew") }
                return try await homebrew.execute(step.action, onLine: onLine)
            }
        }
        for await line in lines {
            currentOutput.append(line)
            if currentOutput.count > 500 { currentOutput.removeFirst(currentOutput.count - 500) }
        }
        switch await task.result {
        case .success(0):
            return .installed
        case .success(let status):
            return .failed(status: status, output: Array(currentOutput.suffix(50)))
        case .failure(let error):
            return .failed(status: -1, output: [Self.describe(error)])
        }
    }
}

// MARK: - Installing Homebrew

extension AppModel {
    /// Downloads Homebrew's official installer package and opens it in
    /// Installer, which handles the admin prompt. casky picks Homebrew up
    /// when its window becomes active again.
    func installHomebrew() async {
        do {
            let package = try await HomebrewInstaller.downloadLatestPackage()
            HomebrewInstaller.open(package)
        } catch {
            alertMessage = "Couldn't download the Homebrew installer: \(Self.describe(error))"
        }
    }
}
