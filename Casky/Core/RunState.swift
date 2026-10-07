import Foundation

/// Progress through an `InstallPlan`, one step at a time. Pure: the caller
/// runs each step and reports how it ended.
///
/// Stop is cooperative: the step in flight finishes, then every remaining
/// step is marked skipped. Nothing is killed mid-install.
struct RunState: Sendable {
    enum Outcome: Equatable, Sendable {
        case installed
        case failed(status: Int32, output: [String])
        case skipped(reason: String)
    }

    let plan: InstallPlan
    private(set) var outcomes: [InstallStep.Action: Outcome] = [:]
    /// The step being run, if any.
    private(set) var current: InstallStep?
    private(set) var stopRequested = false
    /// What a finished step reported, kept for steps whose output says what
    /// changed (dotfiles, preferences).
    private(set) var logs: [InstallStep.Action: [String]] = [:]
    private var nextIndex = 0

    init(plan: InstallPlan) {
        self.plan = plan
    }

    var isFinished: Bool { current == nil && nextIndex >= plan.steps.count }

    var failedCount: Int {
        outcomes.values.filter { if case .failed = $0 { true } else { false } }.count
    }

    /// Hands out the next step to run, or nil when the run is over. Steps whose
    /// prerequisites didn't install are skipped on the way.
    mutating func nextStep() -> InstallStep? {
        precondition(current == nil, "finish the current step first")
        while nextIndex < plan.steps.count {
            let step = plan.steps[nextIndex]
            nextIndex += 1
            if stopRequested {
                outcomes[step.action] = .skipped(reason: "Stopped")
            } else if let blocker = step.prerequisites.first(where: { outcomes[$0] != .installed }) {
                outcomes[step.action] = .skipped(reason: "\(blocker.name) didn't install")
            } else {
                current = step
                return step
            }
        }
        return nil
    }

    mutating func finish(_ outcome: Outcome, log: [String] = []) {
        guard let step = current else { preconditionFailure("no step is running") }
        outcomes[step.action] = outcome
        if !log.isEmpty { logs[step.action] = log }
        current = nil
    }

    mutating func requestStop() {
        stopRequested = true
    }
}
