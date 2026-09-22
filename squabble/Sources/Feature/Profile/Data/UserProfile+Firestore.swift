import Foundation

/// Mapping to and from the `users/{uid}` document. Kept free of Firebase types so it
/// can be tested without the SDK.
nonisolated extension UserProfile {
    enum Field {
        static let displayName = "displayName"
        static let handle = "handle"
        static let avatar = "avatar"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
    }

    init(id: String, firestoreData data: [String: Any]) throws(FirestoreMappingError) {
        guard let displayName = data[Field.displayName] as? String,
              let rawHandle = data[Field.handle] as? String,
              let handle = try? Handle(validating: rawHandle)
        else { throw .malformed("users/\(id)") }
        let avatarData = data[Field.avatar] as? [String: Any] ?? [:]
        self.init(
            id: id,
            displayName: displayName,
            handle: handle,
            avatar: Avatar(firestoreData: avatarData) ?? .preset(.default(for: id))
        )
    }

    /// Timestamps are left to the caller so the write can use server time.
    var firestoreData: [String: Any] {
        [
            Field.displayName: displayName,
            Field.handle: handle.rawValue,
            Field.avatar: avatar.firestoreData,
        ]
    }
}
