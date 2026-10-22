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

    /// Returns once the new name is in the local cache; the server write finishes on its own,
    /// so renaming works offline.
    @discardableResult
    func rename(_ profile: UserProfile, to input: String) throws -> Task<Void, Never> {
        guard let name = UserProfile.validDisplayName(input) else { throw ProfileError.invalidDisplayName }
        var renamed = profile
        renamed.displayName = name
        return Task {
            do {
                try await profiles.updateProfile(renamed)
            } catch {
                AppLog.error(error, "Display name update failed")
            }
        }
    }

    /// Uploads a prepared JPEG and makes it the avatar. The upload needs a connection anyway,
    /// so this waits for the server to accept the profile too, and a rejection is thrown
    /// rather than quietly rolled back.
    func setPhoto(_ jpeg: Data, on profile: UserProfile) async throws {
        var updated = profile
        updated.avatar = try await avatars.upload(jpeg, for: profile.id)
        try await profiles.updateProfile(updated)
        await removeOldPhotos(of: updated)
    }

    /// Personas are only for getting started, so there's no picking one back: the avatar
    /// falls back to a random one, as onboarding preselects. Returns straight away, so it
    /// works offline; the old photo is only deleted once the server has the new avatar.
    @discardableResult
    func removePhoto(from profile: UserProfile) -> Task<Void, Never> {
        var updated = profile
        updated.avatar = Self.randomPersona()
        return Task {
            do {
                try await profiles.updateProfile(updated)
                await removeOldPhotos(of: updated)
            } catch {
                AppLog.error(error, "Avatar photo removal failed")
            }
        }
    }

    static func randomPersona() -> Avatar {
        .persona(
            AvatarPersona.allCases.randomElement() ?? .bigSpender,
            AvatarColor.allCases.randomElement() ?? .meadow
        )
    }

    /// Only after the server has the new avatar: deleting first would leave a rejected
    /// change pointing at a deleted photo. Best effort; anything left behind is swept up by
    /// the next change or by account deletion.
    private func removeOldPhotos(of profile: UserProfile) async {
        do {
            try await avatars.deleteAll(for: profile.id, keeping: profile.avatar.photoPath)
        } catch {
            AppLog.error(error, "Old avatar cleanup failed")
        }
    }
}
