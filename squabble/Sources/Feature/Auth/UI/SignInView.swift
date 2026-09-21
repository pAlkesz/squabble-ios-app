import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthSession.self) private var session
    @State private var isSigningIn = false
    @State private var failure: SignInFailure?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            SquabLogoView(color: .accentColor)
                .frame(width: 120, height: 120)
            Text("Squabble")
                .font(.largeTitle.bold())
            Text("Split the bill. Assign the blame.")
                .font(.title3)
            Text("Sign in so we know whose name to put on the receipt.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            AppleSignInButton(label: .signIn, onCompletion: signIn)
                .disabled(isSigningIn)
                .overlay {
                    if isSigningIn { ProgressView().tint(.white) }
                }
        }
        .padding(24)
        .alert(
            "Sign-in failed",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }),
            presenting: failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
    }

    private func signIn(_ result: Result<AppleSignInResult, Error>) {
        Task {
            isSigningIn = true
            defer { isSigningIn = false }
            do {
                try await session.signIn(with: result.get())
            } catch {
                failure = SignInFailure(message: error.localizedDescription)
            }
        }
    }
}

private struct SignInFailure: Identifiable {
    let id = UUID()
    let message: String
}
