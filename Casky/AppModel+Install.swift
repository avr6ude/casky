import Foundation

extension AppModel {
    /// What installing `items` (the selection by default) would do right now.
    func previewPlan(for items: [Item]? = nil) -> InstallPlan {
        let selection = items ?? selection
        let bundles = selection.compactMap { item in entry(for: item)?.appBundleName.map { (item, $0) } }
        return InstallPlan(
            selection: selection, installed: installed,
            appBundles: Dictionary(bundles, uniquingKeysWith: { first, _ in first }),
            needsAdmin: catalog?.adminItems ?? []
        )
    }

    enum RunKind: Sendable {
        case install([Item])
        case update([Item])
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
        guard !isInstalling, let homebrew else { return }
        isInstalling = true
        defer { isInstalling = false }

        lastRun = kind
        runNote = nil
        currentOutput = []
        do {
            _ = try await homebrew.run(["update"])
        } catch {
            // Not fatal: Homebrew works with the package data it already has.
            runNote = "Couldn't update Homebrew first: \(Self.describe(error))"
        }
        await refreshInstalled()
        switch kind {
        case .install(let items):
            run = RunState(plan: previewPlan(for: items))
        case .update(let items):
            await refreshUpdates()
            run = RunState(plan: InstallPlan(updates: items.compactMap { updates[$0] }))
        }

        while let step = run?.nextStep() {
            currentOutput = []
            // Await first: `run` may change (Stop) while the step runs.
            let outcome = await execute(step, with: homebrew)
            run?.finish(outcome)
        }
        if let run { record(run) }
        // The run is over for the user; refreshing what's installed can
        // take a few seconds and shouldn't keep the sheet on "Installing…".
        isInstalling = false
        await refreshInstalled()
        await refreshUpdates()
    }

    func stopAfterCurrentStep() {
        run?.requestStop()
    }

    func dismissRun() {
        guard !isInstalling else { return }
        run = nil
        currentOutput = []
    }

    private func execute(_ step: InstallStep, with homebrew: Homebrew) async -> RunState.Outcome {
        let (lines, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1000))
        let task = Task.detached {
            defer { continuation.finish() }
            return try await homebrew.execute(step.action) { continuation.yield($0) }
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
