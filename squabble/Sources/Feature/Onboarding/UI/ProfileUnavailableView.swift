import SwiftUI

/// Shown when the profile listener fails outright — without it we can't tell whether
/// the user still needs onboarding, so don't guess.
struct ProfileUnavailableView: View {
    @Environment(AuthSession.self) private var session

    var body: some View {
        ZStack {
            SquabbleBackdrop()
            VStack(spacing: 24) {
                Spacer()
                SquabLogoView()
                    .frame(width: 120)
                OnboardingHeading(
                    title: "We lost your profile",
                    subtitle: "Not your fault. Probably. Try again, and if it keeps happening, sign out and back in."
                )
                .multilineTextAlignment(.center)
                Spacer()
                Button(action: session.retryProfile) {
                    Text("Try again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                Button("Sign out") { try? session.signOut() }
                    .buttonStyle(.glass)
            }
            .padding(24)
            .frame(maxWidth: 560)
        }
        .foregroundStyle(.white)
    }
}
