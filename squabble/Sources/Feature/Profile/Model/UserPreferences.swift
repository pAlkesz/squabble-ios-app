import Foundation

/// Settings that follow the user across devices but aren't part of the public profile.
/// Stored in `users/{uid}/private/preferences`; a missing value means "follow the device".
nonisolated struct UserPreferences: Equatable, Sendable {
    /// Only set once the user picks one, so moving country or changing the phone's region
    /// keeps the automatic default up to date.
    var homeCurrencyCode: String?

    var resolvedHomeCurrencyCode: String {
        homeCurrencyCode ?? Self.deviceCurrencyCode
    }

    /// Follows the phone's Region setting, not its language.
    static var deviceCurrencyCode: String {
        Locale.current.currency?.identifier ?? "EUR"
    }
}
