import AuthenticationServices
import SwiftUI

/// Apple's button, with the nonce dance and credential unpacking done. Cancellation is
/// swallowed — the user just closed the sheet, there's nothing to report.
struct AppleSignInButton: View {
    let label: SignInWithAppleButton.Label
    let onCompletion: (Result<AppleSignInResult, Error>) -> Void

    @State private var rawNonce = AppleSignInNonce.random()

    var body: some View {
        SignInWithAppleButton(label) { request in
            request.requestedScopes = [.fullName]
            request.nonce = AppleSignInNonce.sha256(rawNonce)
        } onCompletion: { result in
            handle(result)
            rawNonce = AppleSignInNonce.random()
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            onCompletion(Result { try AppleSignInResult(authorization: authorization, rawNonce: rawNonce) })
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            onCompletion(.failure(error))
        }
    }
}
