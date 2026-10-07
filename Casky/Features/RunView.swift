import AppKit
import SwiftUI

/// Progress of an install run: one row per step, live output for the step
/// in flight, the original output for failures, then Retry or Done.
struct RunView: View {
    @Environment(AppModel.self) private var model
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
                    StepRow(step: step, outcome: run.outcomes[step.action], log: run.logs[step.action] ?? [], isCurrent: run.current == step)
                }
                if !run.plan.alreadyInstalled.isEmpty {
                    Text("\(run.plan.alreadyInstalled.count) already installed, skipped")
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
            footer
        }
        .padding(24)
        .frame(width: 680, height: 560)
        // Opaque, not the sheet's glass: text over translucent material is
        // drawn with vibrancy, which looks soft on non-Retina displays.
        .background(Color(nsColor: .windowBackgroundColor))
        .interactiveDismissDisabled(model.isInstalling)
    }

    private var finishedCount: Int { run.outcomes.count }

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold())
            if model.isPreparing {
                ProgressView("Updating Homebrew's package list…")
                    .progressViewStyle(.linear)
            } else if model.isInstalling {
                ProgressView(value: Double(finishedCount), total: Double(max(run.plan.steps.count, 1)))
                    .accessibilityLabel("Install progress")
                    .accessibilityValue("\(finishedCount) of \(run.plan.steps.count) done")
            }
        }
    }

    private var title: String {
        if model.isInstalling {
            if run.stopRequested { return "Stopping after this item…" }
            return model.isUpdateRun ? "Updating…" : model.isSetupRun ? "Applying Setup…" : "Installing…"
        }
        if run.plan.steps.isEmpty { return model.isUpdateRun ? "Everything is up to date" : model.isSetupRun ? "Nothing to apply" : "Everything is already installed" }
        if run.stopRequested { return "Stopped" }
        return run.failedCount == 0 ? "All done" : "Finished with \(run.failedCount) \(run.failedCount == 1 ? "problem" : "problems")"
    }

    @ViewBuilder private var footer: some View {
        HStack {
            Spacer()
            if model.isInstalling {
                Button("Stop After This Item") { model.stopAfterCurrentStep() }
                    .disabled(run.stopRequested || model.isPreparing)
            } else {
                if run.failedCount > 0 || run.stopRequested {
                    Button("Retry Unfinished") { Task { await model.retryLastRun() } }
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
    let log: [String]
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
                ConsoleView(lines: model.currentOutput, height: 200)
            }
            if case .installed = outcome, !log.isEmpty {
                StepDetails(lines: log)
            }
            if case .failed(_, let output) = outcome {
                if case .mas(let id, _) = step.action.item {
                    // Paid apps not yet bought, or App Store sign-in, need the App Store itself.
                    Button("Open in App Store") {
                        if let url = URL(string: "macappstore://apps.apple.com/app/id\(id)") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
                if !output.isEmpty {
                    StepDetails(lines: output)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String { model.title(for: step.action) }

    /// What the step did, and what it's doing while it runs.
    private var verbs: (done: String, running: String) {
        switch step.action {
        case .tap, .install: ("Installed", "Installing…")
        case .update, .replace: ("Updated", "Updating…")
        case .remove: ("Removed", "Removing…")
        case .hold: ("Held", "Holding…")
        case .editorExtension: ("Installed", "Installing…")
        case .dotfiles, .preferences: ("Done", "Applying…")
        }
    }

    private var detail: String {
        switch outcome {
        case .installed: verbs.done
        case .failed(let status, _): "Failed (exit \(status))"
        case .skipped(let reason): "Skipped: \(reason)"
        case nil: isCurrent ? verbs.running : "Waiting"
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

/// A step's output behind a Details toggle. DisclosureGroup inside a List
/// row draws no chevron and doesn't expand on macOS.
private struct StepDetails: View {
    let lines: [String]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text("Details")
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right").imageScale(.small)
                }
            }
            .buttonStyle(.link)
            .font(.callout)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            if isExpanded {
                ConsoleView(lines: lines, height: 140)
            }
        }
    }
}

/// Command output the way a terminal shows it: full-size monospaced text on
/// a dark background, scrollable and selectable, following new lines.
struct ConsoleView: View {
    let lines: [String]
    let height: CGFloat

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(lines.joined(separator: "\n"))
                    .font(.system(size: 12, design: .monospaced))
                    .lineSpacing(2)
                    .foregroundStyle(Color(white: 0.88))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                Color.clear.frame(height: 1).id("end")
            }
            .frame(height: height)
            .background(Color(white: 0.08), in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            .environment(\.colorScheme, .dark)
            .onAppear { proxy.scrollTo("end", anchor: .bottom) }
            .onChange(of: lines.count) { proxy.scrollTo("end", anchor: .bottom) }
        }
    }
}
