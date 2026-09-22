import Foundation
import Testing
@testable import squabble

@MainActor
struct AuthSessionTests {
    private let service = FakeAuthService()
    private let profiles = FakeProfileRepository()
    private let avatars = FakeAvatarStore()
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

    private func makeSession() -> AuthSession {
        AuthSession(service: service, profiles: profiles, avatars: avatars)
    }

    private func profile(uid: String = "uid-1", handle: String = "pal") throws -> UserProfile {
        UserProfile(id: uid, displayName: "Pal", handle: try Handle(validating: handle), avatar: .preset(.coral))
    }

    @Test func startsLoadingThenReflectsSignedOutBackend() async {
        let session = makeSession()
        #expect(session.state == .loading)

        let observing = Task { await session.observe() }
        await waitUntil { session.state == .signedOut }
        observing.cancel()
    }

    @Test func firstSignInNeedsOnboarding() async throws {
        let session = makeSession()
        let observing = Task { await session.observe() }
        await waitUntil { session.state == .signedOut }

        try await session.signIn(with: apple)
        await waitUntil { session.state == .needsOnboarding(AppUser(id: "uid-1", displayName: "Pal")) }
        #expect(session.profile == nil)
        observing.cancel()
    }

    @Test func returningUserWithProfileIsSignedIn() async throws {
        let existing = try profile()
        profiles.seed(existing)
        let session = makeSession()
        let observing = Task { await session.observe() }

        try await session.signIn(with: apple)
        await waitUntil { session.profile == existing }
        #expect(session.state == .signedIn(AppUser(id: "uid-1", displayName: "Pal"), existing))
        observing.cancel()
    }

    @Test func creatingTheProfileFinishesOnboarding() async throws {
        let session = makeSession()
        let observing = Task { await session.observe() }
        try await session.signIn(with: apple)
        await waitUntil { if case .needsOnboarding = session.state { true } else { false } }

        let created = try profile()
        try await profiles.createProfile(created, paymentMethods: [])
        await waitUntil { session.profile == created }
        observing.cancel()
    }

    @Test func listenerFailureReportsProfileUnavailable() async throws {
        profiles.listenerError = FirestoreMappingError.malformed("users/uid-1")
        let session = makeSession()
        let observing = Task { await session.observe() }

        try await session.signIn(with: apple)
        await waitUntil { if case .profileUnavailable = session.state { true } else { false } }
        observing.cancel()
    }

    @Test func signOutReturnsToSignedOut() async throws {
        let session = makeSession()
        let observing = Task { await session.observe() }
        try await session.signIn(with: apple)
        await waitUntil { session.user != nil }

        try session.signOut()
        await waitUntil { session.state == .signedOut }
        observing.cancel()
    }

    @Test func deleteAccountWipesDataRevokesAppleTokenAndSignsOut() async throws {
        let existing = try profile()
        profiles.seed(existing)
        let session = makeSession()
        let observing = Task { await session.observe() }
        try await session.signIn(with: apple)
        await waitUntil { session.profile != nil }

        try await session.deleteAccount(confirmingWith: apple)
        #expect(avatars.deletedUIDs == ["uid-1"])
        #expect(profiles.deletedUIDs == ["uid-1"])
        #expect(try await profiles.isHandleAvailable(existing.handle, for: "someone-else"))
        #expect(service.revokedCodes == ["code"])
        await waitUntil { session.state == .signedOut }
        observing.cancel()
    }

    @Test func failedReauthenticationDeletesNothing() async throws {
        profiles.seed(try profile())
        service.reauthenticationError = AuthError.missingIdentityToken
        let session = makeSession()
        let observing = Task { await session.observe() }
        try await session.signIn(with: apple)
        await waitUntil { session.profile != nil }

        await #expect(throws: AuthError.self) {
            try await session.deleteAccount(confirmingWith: apple)
        }
        #expect(profiles.deletedUIDs.isEmpty)
        #expect(avatars.deletedUIDs.isEmpty)
        #expect(session.profile != nil)
        observing.cancel()
    }

    @Test func signInFailurePropagatesAndLeavesStateUntouched() async {
        service.signInError = AuthError.unavailable
        let session = makeSession()
        let observing = Task { await session.observe() }
        await waitUntil { session.state == .signedOut }

        await #expect(throws: AuthError.self) {
            try await session.signIn(with: apple)
        }
        #expect(session.state == .signedOut)
        observing.cancel()
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
        #expect(condition())
    }
}
