import FactoryKit
import Foundation

/// Changes to a finished profile, made from the account screen. The handle is fixed here;
/// changing it would mean releasing and claiming handle locks in a transaction.
nonisolated struct ProfileEditor: Sendable {
    private let profiles: ProfileRepository
    private let avatars: AvatarStore

    init(
        profiles: ProfileRepository = Container.shared.profileRepository(),
        avatars: AvatarStore = Container.shared.avatarStore()
    ) {
        self.profiles = profiles
        self.avatars = avatars
    }

    func rename(_ profile: UserProfile, to input: String) throws {
        guard let name = UserProfile.validDisplayName(input) else { throw ProfileError.invalidDisplayName }
        var renamed = profile
        renamed.displayName = name
        try profiles.updateProfile(renamed)
    }

    /// Uploads a prepared JPEG and makes it the avatar. Needs a connection for the upload.
    func setPhoto(_ jpeg: Data, on profile: UserProfile) async throws {
        var updated = profile
        updated.avatar = try await avatars.upload(jpeg, for: profile.id)
        try profiles.updateProfile(updated)
        await removeOldPhotos(of: updated)
    }

    /// Personas are only for getting started, so there's no picking one back: the avatar
    /// falls back to a random one, as onboarding preselects.
    func removePhoto(from profile: UserProfile) async throws {
        var updated = profile
        updated.avatar = Self.randomPersona()
        try profiles.updateProfile(updated)
        await removeOldPhotos(of: updated)
    }

    static func randomPersona() -> Avatar {
        .persona(
            AvatarPersona.allCases.randomElement() ?? .bigSpender,
            AvatarColor.allCases.randomElement() ?? .meadow
        )
    }

    /// Best effort: the avatar has already changed, and a photo left behind now is swept up
    /// by the next change or by account deletion.
    private func removeOldPhotos(of profile: UserProfile) async {
        do {
            try await avatars.deleteAll(for: profile.id, keeping: profile.avatar.photoPath)
        } catch {
            AppLog.error(error, "Old avatar cleanup failed")
        }
    }
}
