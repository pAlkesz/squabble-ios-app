import FactoryKit
import Observation

/// App-wide sign-in state, including whether the signed-in user has a profile yet.
/// Created once at the root and shared via `.environment`.
@Observable
final class AuthSession {
    enum State: Equatable {
        case loading
        case signedOut
        /// Signed in with Apple, but hasn't finished onboarding.
        case needsOnboarding(AppUser)
        case signedIn(AppUser, UserProfile)
    }

    /// Whether the profile listener is alive. A failure leaves `state` at its last known
    /// value, so it's shown over whatever screen is up instead of replacing it.
    enum ProfileSync: Equatable {
        case live
        /// Offline with nothing cached, or the server refused; needs a retry.
        case failed
        case retrying
    }

    private enum AuthState: Equatable {
        case loading
        case signedOut
        case signedIn(AppUser)
    }

    private enum ProfileState: Equatable {
        case loading
        case missing
        case loaded(UserProfile)
    }

    private var authState: AuthState = .loading
    private var profileState: ProfileState = .loading
    private(set) var profileSync: ProfileSync = .live
    private var profileObservation: Task<Void, Never>?

    private let service: AuthService
    private let profiles: ProfileRepository

    init(
        service: AuthService = Container.shared.authService(),
        profiles: ProfileRepository = Container.shared.profileRepository()
    ) {
        self.service = service
        self.profiles = profiles
    }

    var state: State {
        let user: AppUser
        switch authState {
        case .loading: return .loading
        case .signedOut: return .signedOut
        case .signedIn(let signedIn): user = signedIn
        }
        switch profileState {
        case .loading: return .loading
        case .missing: return .needsOnboarding(user)
        case .loaded(let profile): return .signedIn(user, profile)
        }
    }

    var user: AppUser? {
        if case .signedIn(let user) = authState { return user }
        return nil
    }

    /// Signed in and still finding out whether there's a profile, with nothing gone wrong.
    var isLoadingProfile: Bool {
        user != nil && profileState == .loading && profileSync == .live
    }

    var profile: UserProfile? {
        if case .loaded(let profile) = profileState { return profile }
        return nil
    }

    /// Runs for the lifetime of the root view and mirrors the auth backend's state.
    func observe() async {
        defer { profileObservation?.cancel() }
        for await user in service.authStateChanges() {
            let next = user.map(AuthState.signedIn) ?? .signedOut
            // Re-emits for the same user mustn't restart the profile listener.
            guard next != authState else { continue }
            authState = next
            observeProfile(of: user)
        }
    }

    /// Starts listening again after a failure, keeping the last known state meanwhile.
    func retryProfile() {
        guard profileSync == .failed else { return }
        profileSync = .retrying
        observeProfile(of: user, keepingLastKnown: true)
    }

    func signIn(with apple: AppleSignInResult) async throws {
        try await service.signIn(with: apple)
    }

    func signOut() throws {
        try service.signOut()
    }

    /// Deleting the Auth user is the only data step here: the `deleteUserData` Cloud Function
    /// wipes the profile, handle and photos once it's gone, retrying until it succeeds. So a
    /// failure at any point leaves either the whole account or none of it.
    func deleteAccount(confirmingWith apple: AppleSignInResult) async throws {
        guard user != nil else { throw AuthError.notSignedIn }
        try await service.reauthenticate(with: apple)
        // Before the user goes: revoking needs them signed in, and if Apple refuses, nothing
        // has been deleted yet.
        try await service.revokeAppleAccess(apple)
        try await service.deleteUser()
    }

    private func observeProfile(of user: AppUser?, keepingLastKnown: Bool = false) {
        profileObservation?.cancel()
        if !keepingLastKnown {
            profileState = .loading
            profileSync = .live
        }
        guard let user else { return }
        profileObservation = Task { [profiles] in
            do {
                for try await profile in profiles.profileChanges(for: user.id) {
                    guard !Task.isCancelled else { return }
                    profileState = profile.map(ProfileState.loaded) ?? .missing
                    profileSync = .live
                }
            } catch {
                guard !Task.isCancelled else { return }
                if error as? ProfileError != .offline {
                    AppLog.error(error, "Profile listener failed")
                }
                profileSync = .failed
            }
        }
    }
}
