import FirebaseCore
import FirebaseFirestore

/// `groups/{id}`, readable only by its current members (`memberIds`); `firestore.rules`
/// enforces the same shape.
nonisolated final class FirestoreGroupRepository: GroupRepository {
    private var db: Firestore? {
        FirebaseApp.app() == nil ? nil : Firestore.firestore()
    }

    func groupChanges(for uid: String) -> AsyncThrowingStream<[SquabbleGroup], Error> {
        guard let db else {
            return AsyncThrowingStream { $0.finish(throwing: GroupError.unavailable) }
        }
        // No `orderBy`: with `array-contains` it would need a composite index, and the list
        // is small enough to sort on the device.
        let query = db.collection("groups").whereField(SquabbleGroup.Field.memberIds, arrayContains: uid)
        return AsyncThrowingStream { continuation in
            nonisolated(unsafe) let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot else { return }
                let groups = snapshot.documents.compactMap { document -> SquabbleGroup? in
                    // Estimated, so a group created offline sorts by now rather than by nothing.
                    let data = Self.convertingTimestamps(document.data(with: .estimate))
                    do {
                        var group = try SquabbleGroup(id: document.documentID, firestoreData: data)
                        // Unestimated, the creation time is null until the server has set it.
                        group.isAwaitingServer = document.get(SquabbleGroup.Field.createdAt) is NSNull
                        return group
                    } catch {
                        AppLog.error(error, "Unreadable group")
                        return nil
                    }
                }
                continuation.yield(groups)
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func createGroup(_ group: SquabbleGroup) throws {
        guard let db else { throw GroupError.unavailable }
        var data = group.firestoreData
        data[SquabbleGroup.Field.createdAt] = FieldValue.serverTimestamp()
        data[SquabbleGroup.Field.updatedAt] = FieldValue.serverTimestamp()
        data[SquabbleGroup.Field.members] = group.members.mapValues { member in
            var entry = member.firestoreData
            entry[GroupMember.Field.joinedAt] = FieldValue.serverTimestamp()
            return entry
        }
        db.collection("groups").document(group.id).setData(data) { error in
            if let error { AppLog.error(error, "Group creation failed") }
        }
    }

    func updateOwnEntry(_ member: GroupMember, in groupID: String) throws {
        guard let db else { throw GroupError.unavailable }
        // Field by field, so `joinedAt` and anything else on the entry stays as it is.
        var fields: [FieldPath: Any] = [:]
        for (key, value) in member.firestoreData {
            fields[FieldPath([SquabbleGroup.Field.members, member.id, key])] = value
        }
        if member.handle == nil {
            fields[FieldPath([SquabbleGroup.Field.members, member.id, GroupMember.Field.handle])] = FieldValue.delete()
        }
        db.collection("groups").document(groupID).updateData(fields) { error in
            if let error { AppLog.error(error, "Group member entry update failed") }
        }
    }

    /// Firestore hands back `Timestamp`s, nested ones included; the mapping expects `Date`s.
    private static func convertingTimestamps(_ data: [String: Any]) -> [String: Any] {
        data.mapValues(convertingTimestamps(in:))
    }

    private static func convertingTimestamps(in value: Any) -> Any {
        switch value {
        case let timestamp as Timestamp:
            timestamp.dateValue()
        case let map as [String: Any]:
            convertingTimestamps(map)
        case let list as [Any]:
            list.map(convertingTimestamps(in:))
        default:
            value
        }
    }
}
