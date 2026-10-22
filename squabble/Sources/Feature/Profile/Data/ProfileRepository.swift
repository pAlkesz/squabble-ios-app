nonisolated protocol ProfileRepository: Sendable {
    /// Emits `nil` when the user has no profile yet (i.e. hasn't finished onboarding),
    /// then every change, until cancelled. Only emits "missing" once the server has
    /// confirmed it — an empty cache on a fresh install proves nothing. If the server
    /// can't be asked (offline, or it errors), the stream fails rather than waiting.
    func profileChanges(for uid: String) -> AsyncThrowingStream<UserProfile?, Error>

    /// Advisory only; `createProfile` is what actually claims the handle.
    func isHandleAvailable(_ handle: Handle, for uid: String) async throws -> Bool

    /// Claims the handle and writes the profile and payment methods atomically.
    /// Needs a connection: handle uniqueness can't be settled from the local cache.
    func createProfile(_ profile: UserProfile, paymentMethods: [PaymentMethod]) async throws

    /// Saves the display name and avatar; the handle never changes here. The change shows
    /// from the local cache straight away, but this only returns once the server has
    /// accepted it (offline, that means waiting for a connection). A rejected write is
    /// rolled back in the cache and thrown here.
    func updateProfile(_ profile: UserProfile) async throws

    // The writes below land in the local cache straight away and sync when they can; they
    // only throw if the write can't be made at all.

    /// The owner's payment methods, from the cache first, then every change.
    func paymentMethodChanges(for uid: String) -> AsyncThrowingStream<[PaymentMethod], Error>

    func setPaymentMethods(_ methods: [PaymentMethod], for uid: String) throws

    func preferenceChanges(for uid: String) -> AsyncThrowingStream<UserPreferences, Error>

    func setPreferences(_ preferences: UserPreferences, for uid: String) throws

    /// Removes everything stored for the user, including releasing their handle.
    func deleteProfile(_ profile: UserProfile?, uid: String) async throws
}
