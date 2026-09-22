import Foundation

nonisolated protocol AvatarStore: Sendable {
    /// Uploads a prepared JPEG and returns the avatar pointing at it.
    func upload(_ jpeg: Data, for uid: String) async throws -> Avatar

    func deleteAll(for uid: String) async throws
}
