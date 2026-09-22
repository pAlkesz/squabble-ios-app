nonisolated protocol ProfileRepository: Sendable {
    /// Emits `nil` when the user has no profile yet (i.e. hasn't finished onboarding),
    /// then every change, until cancelled. Only emits "missing" once the server has
    /// confirmed it — an empty cache on a fresh install proves nothing.
    func profileChanges(for uid: String) -> AsyncThrowingStream<UserProfile?, Error>

    /// Advisory only; `createProfile` is what actually claims the handle.
    func isHandleAvailable(_ handle: Handle, for uid: String) async throws -> Bool

    /// Claims the handle and writes the profile and payment methods atomically.
    /// Needs a connection: handle uniqueness can't be settled from the local cache.
    func createProfile(_ profile: UserProfile, paymentMethods: [PaymentMethod]) async throws

    /// Removes everything stored for the user, including releasing their handle.
    func deleteProfile(_ profile: UserProfile?, uid: String) async throws
}
