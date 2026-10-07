import SwiftUI

/// First-run setup: get Homebrew and mas, answer a few "which app do you
/// use for…" questions, then install everything picked in one go. Shown
/// full-window on first launch and from Start afterwards. Skip leaves at
/// any point.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    /// Called on Skip or after Install / Finish.
    let finish: () -> Void

    @State private var page = 0
    @State private var picks: [Item] = []
    private let steps = OnboardingStep.bundled()

    /// Page 0 is tool setup, then one page per step, then the review.
    private var reviewPage: Int { steps.count + 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            Group {
                if page == 0 {
                    SetupToolsPage()
                } else if page == reviewPage {
                    ReviewPage(picks: picks) { item in picks.removeAll { $0 == item } }
                } else {
                    StepPage(step: steps[page - 1], picks: $picks)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(page)
            Divider()
            bottomBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var topBar: some View {
        HStack {
            Text(page == 0 ? "Welcome to casky" : page == reviewPage ? "Review" : "Step \(page) of \(steps.count)")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            if !picks.isEmpty {
                Text("^[\(picks.count) app](inflect: true) picked")
                    .foregroundStyle(.secondary)
            }
            Button("Skip Setup", action: finish)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button("Back") { page -= 1 }
            }
            Spacer()
            if page == reviewPage {
                if picks.isEmpty {
                    Button("Finish", action: finish)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Install ^[\(picks.count) App](inflect: true)") {
                        let items = picks
                        finish()
                        Task { await model.install(items) }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.homebrew == nil || model.isInstalling)
                }
            } else {
                let stepPicked = page > 0 && steps[page - 1].options.contains(where: picks.contains)
                Button(page == 0 || stepPicked ? "Continue" : "Skip This") { page += 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Pages

/// Homebrew and mas, one click each.
private struct SetupToolsPage: View {
    @Environment(AppModel.self) private var model
    @State private var installingHomebrew = false

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("Set up this Mac in a few clicks")
                    .font(.largeTitle.bold())
                Text("Pick the apps you use and casky installs them for you. It works with Homebrew, and with mas for App Store apps.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }
            VStack(spacing: 0) {
                ToolRow(
                    name: "Homebrew",
                    detail: "Installs apps and command-line tools.",
                    symbol: "shippingbox",
                    isReady: model.homebrew != nil,
                    isWorking: installingHomebrew,
                    actionTitle: "Install Homebrew"
                ) {
                    installingHomebrew = true
                    Task {
                        await model.installHomebrew()
                        installingHomebrew = false
                    }
                }
                Divider().padding(.leading, 56)
                ToolRow(
                    name: "mas",
                    detail: model.homebrew == nil ? "Installs App Store apps. Needs Homebrew first." : "Installs App Store apps.",
                    symbol: "bag",
                    isReady: model.homebrew?.masExecutable != nil,
                    isWorking: model.isInstalling,
                    actionTitle: "Install mas"
                ) {
                    Task { await model.install([.formula(.masTool)]) }
                }
                .disabled(model.homebrew == nil)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: 560)
            .background(.fill.quinary, in: .rect(cornerRadius: 12))
            if installingHomebrew || (model.homebrew == nil && !installingHomebrew) {
                Text("Homebrew's installer opens in a separate window. casky notices when it's done.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
    }
}

private struct ToolRow: View {
    let name: String
    let detail: String
    let symbol: String
    let isReady: Bool
    let isWorking: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
            Spacer()
            if isReady {
                Pill.installed
            } else if isWorking {
                ProgressView().controlSize(.small)
            } else {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
    }
}

/// One question: a grid of app tiles, pick any.
private struct StepPage: View {
    @Environment(AppModel.self) private var model
    let step: OnboardingStep
    @Binding var picks: [Item]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: step.symbol)
                        .font(.system(size: 36))
                        .foregroundStyle(.tint)
                    Text(step.title).font(.largeTitle.bold())
                    Text(step.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                if model.catalog == nil {
                    ProgressView("Loading apps…")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)], spacing: 16) {
                        ForEach(step.options, id: \.self) { item in
                            AppTile(
                                entry: model.displayEntry(for: item),
                                isPicked: picks.contains(item),
                                isInstalled: model.isInstalled(item)
                            ) {
                                if let index = picks.firstIndex(of: item) { picks.remove(at: index) } else { picks.append(item) }
                            }
                        }
                    }
                    .frame(maxWidth: 820)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct AppTile: View {
    let entry: CatalogEntry
    let isPicked: Bool
    let isInstalled: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(spacing: 10) {
                ItemIcon(entry: entry, size: 56)
                Text(entry.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 34, alignment: .top)
                Text(isInstalled ? "Installed" : entry.item.kind == .mas ? "App Store" : " ")
                    .font(.caption)
                    .foregroundStyle(isInstalled ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(isPicked ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.fill.quinary), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isPicked ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
            }
            .overlay(alignment: .topTrailing) {
                if isPicked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .padding(8)
                }
            }
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isInstalled)
        .opacity(isInstalled ? 0.6 : 1)
        .help(entry.summary ?? entry.title)
        .accessibilityLabel(entry.title)
        .accessibilityValue(isInstalled ? "Installed" : isPicked ? "Picked" : "Not picked")
    }
}

/// Everything picked, with a way to drop items before installing.
private struct ReviewPage: View {
    @Environment(AppModel.self) private var model
    let picks: [Item]
    let remove: (Item) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text(picks.isEmpty ? "Nothing picked" : "Ready to install").font(.largeTitle.bold())
                    Text(picks.isEmpty
                         ? "That's fine: browse apps, kits and the App Store any time from the sidebar."
                         : "casky installs these one by one. Apps that need approval ask for Touch ID or your password.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)], spacing: 16) {
                    ForEach(picks, id: \.self) { item in
                        AppTile(entry: model.displayEntry(for: item), isPicked: true, isInstalled: false) { remove(item) }
                    }
                }
                .frame(maxWidth: 820)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }
}
