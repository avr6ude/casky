import SwiftUI

/// Progress of an install run: one row per step, live output for the step
/// in flight, the original output for failures, then Retry or Done.
struct RunView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let run: RunState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let note = model.runNote {
                Label(note, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            List {
                ForEach(run.plan.steps, id: \.self) { step in
                    StepRow(step: step, outcome: run.outcomes[step.action], isCurrent: run.current == step)
                }
                if !run.plan.alreadyInstalled.isEmpty {
                    Text("\(run.plan.alreadyInstalled.count) already installed, skipped")
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            footer
        }
        .padding(24)
        .frame(minWidth: 600, idealWidth: 680, minHeight: 460, idealHeight: 560)
        .interactiveDismissDisabled(model.isInstalling)
        .animation(reduceMotion ? nil : .default, value: run.outcomes.count)
    }

    private var finishedCount: Int { run.outcomes.count }

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold())
            if model.isInstalling {
                ProgressView(value: Double(finishedCount), total: Double(max(run.plan.steps.count, 1)))
                    .accessibilityLabel("Install progress")
                    .accessibilityValue("\(finishedCount) of \(run.plan.steps.count) done")
            }
        }
    }

    private var title: String {
        if model.isInstalling { return run.stopRequested ? "Stopping after this item…" : "Installing…" }
        if run.plan.steps.isEmpty { return "Everything is already installed" }
        if run.stopRequested { return "Stopped" }
        return run.failedCount == 0 ? "All done" : "Finished with \(run.failedCount) \(run.failedCount == 1 ? "problem" : "problems")"
    }

    @ViewBuilder private var footer: some View {
        HStack {
            Spacer()
            if model.isInstalling {
                Button("Stop After This Item") { model.stopAfterCurrentStep() }
                    .disabled(run.stopRequested)
            } else {
                if run.failedCount > 0 || run.stopRequested {
                    Button("Retry Unfinished") { Task { await model.install() } }
                }
                Button("Done") { model.dismissRun() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }
}

private struct StepRow: View {
    @Environment(AppModel.self) private var model
    let step: InstallStep
    let outcome: RunState.Outcome?
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                status.frame(width: 18)
                Text(title)
                Spacer()
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if isCurrent, !model.currentOutput.isEmpty {
                OutputText(lines: model.currentOutput.suffix(12))
            }
            if case .failed(_, let output) = outcome, !output.isEmpty {
                DisclosureGroup("Details") {
                    OutputText(lines: output[...])
                }
                .font(.callout)
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        switch step.action {
        case .tap(let tap): "Add tap \(tap)"
        case .install(let item): model.displayEntry(for: item).title
        }
    }

    private var detail: String {
        switch outcome {
        case .installed: "Installed"
        case .failed(let status, _): "Failed (exit \(status))"
        case .skipped(let reason): "Skipped: \(reason)"
        case nil: isCurrent ? "Installing…" : "Waiting"
        }
    }

    @ViewBuilder private var status: some View {
        switch outcome {
        case .installed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        case .skipped:
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        case nil:
            if isCurrent {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "circle").foregroundStyle(.tertiary)
            }
        }
    }
}

private struct OutputText: View {
    let lines: ArraySlice<String>

    var body: some View {
        Text(lines.joined(separator: "\n"))
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.fill.quaternary, in: .rect(cornerRadius: 6))
    }
}
