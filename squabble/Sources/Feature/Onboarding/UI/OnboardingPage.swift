import SwiftUI

/// Chrome for one pushed onboarding step: scrolling content on the backdrop, with the
/// page indicator and the primary button pinned to the bottom. Back navigation is the
/// system's own, from the enclosing `NavigationStack`.
struct OnboardingPage<Content: View>: View {
    let step: OnboardingStep
    let primaryTitle: LocalizedStringKey
    let canContinue: Bool
    let isSubmitting: Bool
    let onContinue: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .background { SquabbleBackdrop() }
        .foregroundStyle(.white)
        .disabled(isSubmitting)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSubmitting)
    }

    private var bottomBar: some View {
        VStack(spacing: 20) {
            OnboardingPageIndicator(step: step)
            Button(action: onContinue) {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(primaryTitle)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .disabled(!canContinue || isSubmitting)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
    }
}
