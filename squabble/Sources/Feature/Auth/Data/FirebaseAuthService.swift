import FirebaseAuth
import FirebaseCore

nonisolated final class FirebaseAuthService: AuthService {
    private var auth: Auth? {
        FirebaseApp.app() == nil ? nil : Auth.auth()
    }

    var currentUser: AppUser? {
        auth?.currentUser.map(AppUser.init)
    }

    func authStateChanges() -> AsyncStream<AppUser?> {
        guard let auth else {
            return AsyncStream { continuation in
                continuation.yield(nil)
                continuation.finish()
            }
        }
        return AsyncStream { continuation in
            nonisolated(unsafe) let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user.map(AppUser.init))
            }
            continuation.onTermination = { _ in
                auth.removeStateDidChangeListener(handle)
            }
        }
    }

    func signIn(with apple: AppleSignInResult) async throws {
        guard let auth else { throw AuthError.unavailable }
        let result = try await auth.signIn(with: credential(from: apple))

        // Apple only hands over the name on the very first authorization; Firebase applies it
        // for new users, but make sure it lands if a stale user record has none.
        if result.user.displayName == nil, let name = apple.fullName?.formatted(), !name.isEmpty {
            let change = result.user.createProfileChangeRequest()
            change.displayName = name
            try await change.commitChanges()
        }
    }

    func signOut() throws {
        try auth?.signOut()
    }

    func reauthenticate(with apple: AppleSignInResult) async throws {
        guard let auth else { throw AuthError.unavailable }
        guard let user = auth.currentUser else { throw AuthError.notSignedIn }
        try await user.reauthenticate(with: credential(from: apple))
    }

    func deleteAccount(revoking apple: AppleSignInResult) async throws {
        guard let auth else { throw AuthError.unavailable }
        guard let user = auth.currentUser else { throw AuthError.notSignedIn }
        try await auth.revokeToken(withAuthorizationCode: apple.authorizationCode)
        try await user.delete()
    }

    private func credential(from apple: AppleSignInResult) -> AuthCredential {
        OAuthProvider.appleCredential(
            withIDToken: apple.identityToken,
            rawNonce: apple.rawNonce,
            fullName: apple.fullName
        )
    }
}

nonisolated private extension AppUser {
    init(_ user: User) {
        self.init(id: user.uid, displayName: user.displayName)
    }
}
