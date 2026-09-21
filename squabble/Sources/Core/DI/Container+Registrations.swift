import FactoryKit

extension Container {
    var authService: Factory<AuthService> {
        self { FirebaseAuthService() }.singleton
    }
}
