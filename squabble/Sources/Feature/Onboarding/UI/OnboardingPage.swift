import SwiftUI

/// One page of the onboarding pager: its own vertical scroll, sized for readable width.
struct OnboardingPage<Content: View>: View {
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
        // iOS 26's soft fade under the progress bar and the Continue button; iOS 27 no
        // longer defaults to it.
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
    }
}
