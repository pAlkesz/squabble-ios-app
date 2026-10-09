import SwiftUI

/// Sign-in and onboarding in one native navigation stack: signing in pushes the
/// onboarding screen over sign-in. There's no way back from it — no back button, no
/// swipe — since a signed-in user without a profile has nowhere to go on sign-in; they
/// finish onboarding and can sign out later from their account.
struct OnboardingFlowView: View {
    @Environment(AuthSession.self) private var session
    @State private var onboardingUser: AppUser?

    var body: some View {
        NavigationStack {
            SignInView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $onboardingUser) { user in
                    OnboardingView(user: user)
                }
        }
        .onChange(of: session.state, initial: true) { previous, state in
            sync(with: state, animated: previous != state)
        }
    }

    private func sync(with state: AuthSession.State, animated: Bool) {
        switch state {
        case .needsOnboarding(let user):
            guard onboardingUser != user else { return }
            // Relaunching mid-onboarding lands on it directly, without a push.
            var transaction = Transaction()
            transaction.disablesAnimations = !animated
            withTransaction(transaction) { onboardingUser = user }
        case .signedOut:
            onboardingUser = nil
        case .loading, .signedIn:
            break
        }
    }
}
