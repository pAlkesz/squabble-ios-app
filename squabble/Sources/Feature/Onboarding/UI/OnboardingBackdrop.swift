import SwiftUI

/// Traffic-light progress behind the onboarding steps: a colour at the top fading to
/// black, reaching further down each step — traffic-light red to a third of the screen,
/// amber to two thirds, green all the way. The red leans towards orange so the first
/// step doesn't read as an error screen.
/// Built as a mesh so SwiftUI animates both the colour and how far the fade reaches.
struct OnboardingBackdrop: View {
    let step: OnboardingStep

    var body: some View {
        MeshGradient(
            width: 2,
            height: 3,
            points: [
                [0, 0], [1, 0],
                [0, fadeEnd], [1, fadeEnd],
                [0, 1], [1, 1],
            ],
            colors: [
                color, color,
                .black, .black,
                .black, .black,
            ]
        )
        .ignoresSafeArea()
    }

    private var color: Color {
        switch step {
        case .name: .onboardingRed
        case .avatar: .onboardingAmber
        case .payment: Color(.accent)
        }
    }

    /// Where the fade reaches black, as a fraction of the screen height. Kept just short
    /// of 1 so the mesh's middle row never collapses onto the bottom one.
    private var fadeEnd: Float {
        switch step {
        case .name: 0.33
        case .avatar: 0.66
        case .payment: 0.999
        }
    }
}

#Preview {
    HStack(spacing: 0) {
        ForEach(OnboardingStep.allCases, id: \.self) { step in
            OnboardingBackdrop(step: step)
        }
    }
}
