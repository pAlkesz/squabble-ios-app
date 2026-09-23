import SwiftUI

struct OnboardingPageIndicator: View {
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(.white.opacity(item <= step ? 1 : 0.3))
                    .frame(width: item == step ? 28 : 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)"))
    }
}
