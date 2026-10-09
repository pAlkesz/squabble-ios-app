import SwiftUI

/// Story-style progress: one segment per step, filled up to the current one. The newly
/// reached segment fills left to right.
struct OnboardingProgressSegments: View {
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(.white.opacity(0.25))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .scaleEffect(x: item <= step ? 1 : 0, anchor: .leading)
                    }
                    .clipShape(.capsule)
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: step)
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)"))
    }
}
