import Foundation

nonisolated protocol GroupImageStore: Sendable {
    /// Uploads a prepared square JPEG for a squabble and returns the image pointing at it.
    /// Needs a connection.
    func upload(_ jpeg: Data, by uid: String) async throws -> SquabbleImage
}
