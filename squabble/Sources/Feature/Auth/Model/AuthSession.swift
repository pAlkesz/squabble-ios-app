import FactoryKit
import Observation

/// App-wide sign-in state. Created once at the root and shared via `.environment`.
@Observable
final class AuthSession {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(AppUser)
    }

    private(set) var state: State = .loading
    private let service: AuthService

    init(service: AuthService = Container.shared.authService()) {
        self.service = service
    }

    var user: AppUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    /// Runs for the lifetime of the root view and mirrors the auth backend's state.
    func observe() async {
        for await user in service.authStateChanges() {
            state = user.map(State.signedIn) ?? .signedOut
        }
    }

    func signIn(with apple: AppleSignInResult) async throws {
        try await service.signIn(with: apple)
    }

    func signOut() throws {
        try service.signOut()
    }

    func deleteAccount(confirmingWith apple: AppleSignInResult) async throws {
        try await service.deleteAccount(reauthenticatingWith: apple)
    }
}
