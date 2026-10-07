import Foundation

extension AppModel {
    /// What Install would do right now, for the confirmation dialog.
    func previewPlan() -> InstallPlan {
        InstallPlan(selection: selection, installed: installed, needsAdmin: catalog?.adminItems ?? [])
    }

    /// Installs the selection one step at a time. Retrying is the same call:
    /// items that installed last time are now installed and drop out.
    func install() async {
        guard !isInstalling, let homebrew else { return }
        isInstalling = true
        defer { isInstalling = false }

        await refreshInstalled()
        run = RunState(plan: previewPlan())
        runNote = nil
        currentOutput = []

        do {
            _ = try await homebrew.run(["update"])
        } catch {
            // Not fatal: installs use the formula data Homebrew already has.
            runNote = "Couldn't update Homebrew first: \(Self.describe(error))"
        }

        while let step = run?.nextStep() {
            currentOutput = []
            // Await first: `run` may change (Stop) while the step runs.
            let outcome = await execute(step, with: homebrew)
            run?.finish(outcome)
        }
        if let run { record(run) }
        await refreshInstalled()
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
        let name = Self.itemName(step.action)
        let task = Task.detached {
            defer { continuation.finish() }
            return try await homebrew.execute(step.action, itemName: name) { continuation.yield($0) }
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

    static func itemName(_ action: InstallStep.Action) -> String {
        switch action {
        case .tap(let tap): tap
        case .install(.formula(let ref)), .install(.cask(let ref)): ref.name
        case .install(.mas(_, let name)): name
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
