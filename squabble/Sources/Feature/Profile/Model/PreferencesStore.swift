import FactoryKit
import Observation

/// The signed-in user's preferences, kept live for as long as home is up and shared with
/// the account screen through the environment.
@Observable
final class PreferencesStore {
    private(set) var preferences = UserPreferences()
    private var uid: String?

    private let profiles: ProfileRepository

    init(profiles: ProfileRepository = Container.shared.profileRepository()) {
        self.profiles = profiles
    }

    var homeCurrencyCode: String {
        preferences.resolvedHomeCurrencyCode
    }

    func observe(uid: String) async {
        self.uid = uid
        do {
            for try await preferences in profiles.preferenceChanges(for: uid) {
                self.preferences = preferences
            }
        } catch {
            // Signing out kills the listener with a permission error; that's not a failure.
            guard !Task.isCancelled else { return }
            AppLog.error(error, "Preferences listener failed")
        }
    }

    /// `nil` goes back to following the device.
    func setHomeCurrency(_ code: String?) throws {
        guard let uid else { throw AuthError.notSignedIn }
        var updated = preferences
        updated.homeCurrencyCode = code
        try profiles.setPreferences(updated, for: uid)
        preferences = updated
    }
}
