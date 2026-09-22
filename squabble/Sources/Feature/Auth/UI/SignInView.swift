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
            // The receipt's own bottom padding fixes how high it sits; the bird then
            // centres itself in whatever space is left above it.
            header
                .frame(maxHeight: .infinity)
            WelcomeReceiptView()
                .padding(.horizontal, 30)
                .padding(.bottom, 96)
            signIn
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var header: some View {
        WelcomeBirdView()
            .frame(width: 270)
    }

    private var signIn: some View {
        AppleSignInButton(label: .signIn, onCompletion: signIn)
            .disabled(isSigningIn)
            .overlay {
                if isSigningIn { ProgressView().tint(.black) }
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
