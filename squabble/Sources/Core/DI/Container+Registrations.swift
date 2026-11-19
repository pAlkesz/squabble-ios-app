import FactoryKit

extension Container {
    var authService: Factory<AuthService> {
        self { FirebaseAuthService() }.singleton
    }

    var profileRepository: Factory<ProfileRepository> {
        self { FirestoreProfileRepository() }.singleton
    }

    var groupRepository: Factory<GroupRepository> {
        self { FirestoreGroupRepository() }.singleton
    }

    var groupImageStore: Factory<GroupImageStore> {
        self { FirebaseGroupImageStore() }.singleton
    }

    var inviteRepository: Factory<InviteRepository> {
        self { FirebaseInviteRepository() }.singleton
    }

    var chatRepository: Factory<ChatRepository> {
        self { FirestoreChatRepository() }.singleton
    }

    var avatarStore: Factory<AvatarStore> {
        self { FirebaseAvatarStore() }.singleton
    }

    var connectivityMonitor: Factory<ConnectivityMonitor> {
        self { NetworkPathConnectivityMonitor() }.singleton
    }
}
