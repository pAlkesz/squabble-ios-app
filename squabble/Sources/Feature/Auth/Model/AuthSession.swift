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
        /// The profile couldn't be loaded — usually rules or a broken document, not the network.
        case profileUnavailable(AppUser)
        case signedIn(AppUser, UserProfile)
    }

    private enum AuthState: Equatable {
        case loading
        case signedOut
        case signedIn(AppUser)
    }

    private enum ProfileState: Equatable {
        case loading
        case missing
        case failed
        case loaded(UserProfile)
    }

    private var authState: AuthState = .loading
    private var profileState: ProfileState = .loading
    private var profileObservation: Task<Void, Never>?
    // Wiping the profile makes the listener report "no profile" a moment before the auth
    // user disappears; without this the onboarding screen would flash mid-deletion.
    private var isDeletingAccount = false

    private let service: AuthService
    private let profiles: ProfileRepository
    private let avatars: AvatarStore

    init(
        service: AuthService = Container.shared.authService(),
        profiles: ProfileRepository = Container.shared.profileRepository(),
        avatars: AvatarStore = Container.shared.avatarStore()
    ) {
        self.service = service
        self.profiles = profiles
        self.avatars = avatars
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
        case .failed: return .profileUnavailable(user)
        case .loaded(let profile): return .signedIn(user, profile)
        }
    }

    var user: AppUser? {
        if case .signedIn(let user) = authState { return user }
        return nil
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

    /// Starts listening again after `profileUnavailable`.
    func retryProfile() {
        observeProfile(of: user)
    }

    func signIn(with apple: AppleSignInResult) async throws {
        try await service.signIn(with: apple)
    }

    func signOut() throws {
        try service.signOut()
    }

    func deleteAccount(confirmingWith apple: AppleSignInResult) async throws {
        guard let user else { throw AuthError.notSignedIn }
        try await service.reauthenticate(with: apple)
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        try await avatars.deleteAll(for: user.id)
        try await profiles.deleteProfile(profile, uid: user.id)
        try await service.deleteAccount(revoking: apple)
    }

    private func observeProfile(of user: AppUser?) {
        profileObservation?.cancel()
        profileState = .loading
        guard let user else { return }
        profileObservation = Task { [profiles] in
            do {
                for try await profile in profiles.profileChanges(for: user.id) {
                    guard !Task.isCancelled else { return }
                    if isDeletingAccount && profile == nil { continue }
                    profileState = profile.map(ProfileState.loaded) ?? .missing
                }
            } catch {
                guard !Task.isCancelled else { return }
                AppLog.error(error, "Profile listener failed")
                profileState = .failed
            }
        }
    }
}
