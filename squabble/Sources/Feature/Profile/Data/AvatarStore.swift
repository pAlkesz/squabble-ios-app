import Foundation

nonisolated protocol AvatarStore: Sendable {
    /// Uploads a prepared JPEG and returns the avatar pointing at it.
    func upload(_ jpeg: Data, for uid: String) async throws -> Avatar

    /// Deletes the user's uploaded photos, except the one at `keeping` (a storage path).
    /// Sweeping everything, not just the previous photo, also cleans up any upload an
    /// earlier failed change left behind.
    func deleteAll(for uid: String, keeping: String?) async throws
}

nonisolated extension AvatarStore {
    func deleteAll(for uid: String) async throws {
        try await deleteAll(for: uid, keeping: nil)
    }
}
