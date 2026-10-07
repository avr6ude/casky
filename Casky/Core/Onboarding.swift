import Foundation

/// One question in first-run setup ("Which browser do you use?") with the
/// apps to choose from. Bundled as `onboarding.json`.
struct OnboardingStep: Codable, Hashable, Identifiable, Sendable {
    let id: String
    /// SF Symbol name.
    let symbol: String
    let title: String
    let subtitle: String
    let options: [Item]

    static func bundled() -> [OnboardingStep] {
        guard let url = Bundle.main.url(forResource: "onboarding", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let steps = try? JSONDecoder().decode([OnboardingStep].self, from: data) else {
            // Bundled and covered by tests; failing here means a broken build.
            preconditionFailure("onboarding.json missing or invalid in the app bundle")
        }
        return steps
    }
}
