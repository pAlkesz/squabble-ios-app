import FirebaseCore
import FirebaseStorage
import Foundation

/// Avatars live at `avatars/{uid}/{random}.jpg`. A fresh name per upload means a new
/// URL, so no one keeps seeing a cached old face.
nonisolated final class FirebaseAvatarStore: AvatarStore {
    private var storage: Storage? {
        FirebaseApp.app() == nil ? nil : Storage.storage()
    }

    func upload(_ jpeg: Data, for uid: String) async throws -> Avatar {
        guard let storage else { throw ProfileError.unavailable }
        let reference = storage.reference(withPath: "avatars/\(uid)/\(UUID().uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await reference.putDataAsync(jpeg, metadata: metadata)
        let url = try await reference.downloadURL()
        return .photo(path: reference.fullPath, url: url)
    }

    func deleteAll(for uid: String) async throws {
        guard let storage else { throw ProfileError.unavailable }
        let listing = try await storage.reference(withPath: "avatars/\(uid)").listAll()
        for item in listing.items {
            try await item.delete()
        }
    }
}
