import Foundation
import Testing
@testable import squabble

@MainActor
struct AuthSessionTests {
    private let service = FakeAuthService()
    private let apple = AppleSignInResult(
        identityToken: "token",
        authorizationCode: "code",
        rawNonce: "nonce",
        fullName: {
            var name = PersonNameComponents()
            name.givenName = "Pal"
            return name
        }()
    )

    @Test func startsLoadingThenReflectsSignedOutBackend() async {
        let session = AuthSession(service: service)
        #expect(session.state == .loading)

        let observing = Task { await session.observe() }
        await waitUntil { session.state == .signedOut }
        observing.cancel()
    }

    @Test func signInTransitionsToSignedInWithUser() async throws {
        let session = AuthSession(service: service)
        let observing = Task { await session.observe() }
        await waitUntil { session.state == .signedOut }

        try await session.signIn(with: apple)
        await waitUntil { session.user != nil }
        #expect(session.user?.displayName == "Pal")
        observing.cancel()
    }

    @Test func signOutReturnsToSignedOut() async throws {
        let session = AuthSession(service: service)
        let observing = Task { await session.observe() }
        try await session.signIn(with: apple)
        await waitUntil { session.user != nil }

        try session.signOut()
        await waitUntil { session.state == .signedOut }
        observing.cancel()
    }

    @Test func deleteAccountRevokesAppleTokenAndSignsOut() async throws {
        let session = AuthSession(service: service)
        let observing = Task { await session.observe() }
        try await session.signIn(with: apple)
        await waitUntil { session.user != nil }

        try await session.deleteAccount(confirmingWith: apple)
        #expect(service.revokedCodes == ["code"])
        await waitUntil { session.state == .signedOut }
        observing.cancel()
    }

    @Test func signInFailurePropagatesAndLeavesStateUntouched() async {
        service.signInError = AuthError.unavailable
        let session = AuthSession(service: service)
        let observing = Task { await session.observe() }
        await waitUntil { session.state == .signedOut }

        await #expect(throws: AuthError.self) {
            try await session.signIn(with: apple)
        }
        #expect(session.state == .signedOut)
        observing.cancel()
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
        #expect(condition())
    }
}
