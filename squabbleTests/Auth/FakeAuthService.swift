import Foundation
@testable import squabble

/// In-memory auth backend: sign-in succeeds with a fixed user, state changes are pushed
/// through a single stream the same way Firebase's listener would.
nonisolated final class FakeAuthService: AuthService, @unchecked Sendable {
    var currentUser: AppUser?
    var signInError: Error?
    private(set) var revokedCodes: [String] = []
    private var continuation: AsyncStream<AppUser?>.Continuation?

    func authStateChanges() -> AsyncStream<AppUser?> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(currentUser)
        }
    }

    func signIn(with apple: AppleSignInResult) async throws {
        if let signInError { throw signInError }
        set(user: AppUser(id: "uid-1", displayName: apple.fullName?.formatted()))
    }

    func signOut() throws {
        set(user: nil)
    }

    func deleteAccount(reauthenticatingWith apple: AppleSignInResult) async throws {
        guard currentUser != nil else { throw AuthError.notSignedIn }
        revokedCodes.append(apple.authorizationCode)
        set(user: nil)
    }

    private func set(user: AppUser?) {
        currentUser = user
        continuation?.yield(user)
    }
}
