import FactoryKit

extension Container {
    var authService: Factory<AuthService> {
        self { FirebaseAuthService() }.singleton
    }

    var profileRepository: Factory<ProfileRepository> {
        self { FirestoreProfileRepository() }.singleton
    }

    var avatarStore: Factory<AvatarStore> {
        self { FirebaseAvatarStore() }.singleton
    }
}
