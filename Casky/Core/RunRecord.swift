import Foundation

/// A finished install run, kept for the History screen.
struct RunRecord: Codable, Hashable, Identifiable, Sendable {
    struct Step: Codable, Hashable, Sendable {
        enum Result: Codable, Hashable, Sendable {
            case installed
            case failed(status: Int32, output: [String])
            case skipped(reason: String)
        }

        let title: String
        let result: Result
    }

    let id: UUID
    let date: Date
    let steps: [Step]
    let alreadyInstalled: Int
    /// Their names, for the tooltip. Missing in records from before.
    var alreadyInstalledNames: [String]? = nil

    var installedCount: Int { steps.filter { $0.result == .installed }.count }
    var failedCount: Int { steps.filter { if case .failed = $0.result { true } else { false } }.count }

    init(run: RunState, date: Date, title: (InstallStep.Action) -> String, itemTitle: (Item) -> String = { $0.technicalName }) {
        id = UUID()
        self.date = date
        alreadyInstalled = run.plan.alreadyInstalled.count
        alreadyInstalledNames = run.plan.alreadyInstalled.map(itemTitle)
        steps = run.plan.steps.map { step in
            let result: Step.Result = switch run.outcomes[step.action] {
            case .installed: .installed
            case .failed(let status, let output): .failed(status: status, output: output)
            case .skipped(let reason): .skipped(reason: reason)
            case nil: .skipped(reason: "Didn't run")
            }
            return Step(title: title(step.action), result: result)
        }
    }

    /// Newest first, at most `limit`.
    static func appending(_ record: RunRecord, to history: [RunRecord], limit: Int = 50) -> [RunRecord] {
        Array(([record] + history).prefix(limit))
    }
}
