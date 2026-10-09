import SwiftUI

/// Shown, undismissable, whenever the profile can't be loaded — over the waiting bird at
/// launch, over sign-in, or over whatever screen is up. Without the profile we can't tell
/// onboarding from home, so the only ways out are a successful retry or signing out.
struct ProfileSyncFailedSheet: View {
    @Environment(AuthSession.self) private var session

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("We can't reach the nest", comment: "Profile failed to load: sheet title.")
                    .font(.title2.bold())
                Text(
                    "Your profile won't load. Usually that's the internet, occasionally it's us. Check your connection and try again.",
                    comment: "Profile failed to load: explanation."
                )
                .font(.body)
                .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            // Default spacing plus 4, matching the ThermalGlass sheets' button pair.
            VStack {
                SquabbleGlassButton(
                    title: "Try again",
                    kind: .prominent,
                    isLoading: session.profileSync == .retrying,
                    action: session.retryProfile
                )
                .padding(.bottom, 4)
                SquabbleGlassButton(title: "Sign out") { try? session.signOut() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 8)
        .frame(maxWidth: 480)
        .fittedSheet()
        .interactiveDismissDisabled()
    }
}
