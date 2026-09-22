import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthSession.self) private var session
    @State private var isSigningIn = false
    @State private var failure: SignInFailure?

    var body: some View {
        ZStack {
            SquabbleBackdrop()
            content
        }
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

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            header
            WelcomeReceiptView()
                .padding(.horizontal, 30)
                .padding(.top, 26)
            Spacer(minLength: 20)
            signIn
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var header: some View {
        VStack(spacing: 10) {
            SquabLogoView(color: .white)
                .frame(width: 84, height: 84)
            Text("Split the bill. Assign the blame.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    private var signIn: some View {
        VStack(spacing: 12) {
            AppleSignInButton(label: .signIn, onCompletion: signIn)
                .disabled(isSigningIn)
                .overlay {
                    if isSigningIn { ProgressView().tint(.black) }
                }
            Text("By continuing you accept that Dave still owes you for brunch.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
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
