import SwiftUI

/// Past install runs, newest first, with what happened to each item.
struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView(
                    "No installs yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Each time casky installs something, it's listed here.")
                )
            } else {
                List(model.history) { record in
                    DisclosureGroup {
                        ForEach(Array(record.steps.enumerated()), id: \.offset) { _, step in
                            HistoryStepRow(step: step)
                        }
                    } label: {
                        HStack {
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.body.weight(.medium))
                            Spacer()
                            Text(summary(record))
                                .foregroundStyle(record.failedCount > 0 ? .red : .secondary)
                                .help(record.alreadyInstalledNames.map { "Already there: \($0.formatted(.list(type: .and)))" } ?? "")
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private func summary(_ record: RunRecord) -> String {
        var parts = ["\(record.installedCount) installed"]
        if record.failedCount > 0 { parts.append("\(record.failedCount) failed") }
        if record.alreadyInstalled > 0 { parts.append("\(record.alreadyInstalled) already there") }
        return parts.joined(separator: ", ")
    }
}

private struct HistoryStepRow: View {
    let step: RunRecord.Step

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                icon.frame(width: 16)
                Text(step.title)
                Spacer()
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            if case .failed(_, let output) = step.result, !output.isEmpty {
                ConsoleView(lines: output, height: 140)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        switch step.result {
        case .installed: "Installed"
        case .failed(let status, _): "Failed (exit \(status))"
        case .skipped(let reason): "Skipped: \(reason)"
        }
    }

    @ViewBuilder private var icon: some View {
        switch step.result {
        case .installed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        case .skipped: Image(systemName: "minus.circle").foregroundStyle(.secondary)
        }
    }
}
