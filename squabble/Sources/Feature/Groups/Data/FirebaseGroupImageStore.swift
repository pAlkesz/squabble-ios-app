import FirebaseCore
import FirebaseStorage
import Foundation

/// Squabble photos live at `groupImages/{uploader uid}/{random}.jpg`: filed by uploader
/// rather than by squabble, so the storage rules can check ownership without reading
/// Firestore, and the upload can happen before the squabble exists. They belong to the
/// squabble, so account deletion leaves them; deleting the squabble removes them.
nonisolated final class FirebaseGroupImageStore: GroupImageStore {
    private var storage: Storage? {
        FirebaseApp.app() == nil ? nil : Storage.storage()
    }

    func upload(_ jpeg: Data, by uid: String) async throws -> SquabbleImage {
        guard let storage else { throw GroupError.unavailable }
        let reference = storage.reference(withPath: "groupImages/\(uid)/\(UUID().uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await reference.putDataAsync(jpeg, metadata: metadata)
        let url = try await reference.downloadURL()
        return .photo(path: reference.fullPath, url: url)
    }
}
