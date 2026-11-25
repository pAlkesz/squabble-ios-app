import FirebaseCore
import FirebaseFirestore

/// `groups/{gid}/messages`, readable by the squabble's current members; reports go to
/// `reports/`, which only the developer reads. `firestore.rules` enforces the same shapes.
nonisolated final class FirestoreChatRepository: ChatRepository {
    private var db: Firestore? {
        FirebaseApp.app() == nil ? nil : Firestore.firestore()
    }

    private func messages(_ db: Firestore, _ groupID: String) -> CollectionReference {
        db.collection("groups").document(groupID).collection("messages")
    }

    func latestMessages(in groupID: String, limit: Int) -> AsyncThrowingStream<FeedPage<ChatMessage>, Error> {
        guard let db else {
            return AsyncThrowingStream { $0.finish(throwing: ChatError.unavailable) }
        }
        let query = messages(db, groupID)
            .order(by: ChatMessage.Field.createdAt, descending: true)
            .limit(to: limit)
        return AsyncThrowingStream { continuation in
            // Metadata changes too, so "not sent yet" clears once the server has a message.
            nonisolated(unsafe) let registration = query.addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot else { return }
                continuation.yield(Self.page(from: snapshot, limit: limit))
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func messages(in groupID: String, before date: Date, limit: Int) async throws -> FeedPage<ChatMessage> {
        guard let db else { throw ChatError.unavailable }
        let snapshot = try await messages(db, groupID)
            .order(by: ChatMessage.Field.createdAt, descending: true)
            .whereField(ChatMessage.Field.createdAt, isLessThan: Timestamp(date: date))
            .limit(to: limit)
            .getDocuments()
        return Self.page(from: snapshot, limit: limit)
    }

    func send(_ message: ChatMessage, in groupID: String) throws {
        guard let db else { throw ChatError.unavailable }
        var data = message.firestoreData
        data[ChatMessage.Field.createdAt] = FieldValue.serverTimestamp()
        let batch = db.batch()
        batch.setData(data, forDocument: messages(db, groupID).document(message.id))
        batch.updateData(
            [SquabbleGroup.Field.updatedAt: FieldValue.serverTimestamp()],
            forDocument: db.collection("groups").document(groupID)
        )
        batch.commit { error in
            if let error { AppLog.error(error, "Message send failed") }
        }
    }

    func setReaction(_ emoji: String?, by uid: String, on messageID: String, in groupID: String) throws {
        guard let db else { throw ChatError.unavailable }
        let field = FieldPath([ChatMessage.Field.reactions, uid])
        messages(db, groupID).document(messageID).updateData([field: emoji ?? FieldValue.delete()]) { error in
            if let error { AppLog.error(error, "Reaction failed") }
        }
    }

    func delete(_ messageID: String, in groupID: String) throws {
        guard let db else { throw ChatError.unavailable }
        messages(db, groupID).document(messageID).updateData([
            ChatMessage.Field.text: FieldValue.delete(),
            ChatMessage.Field.deletedAt: FieldValue.serverTimestamp(),
        ]) { error in
            if let error { AppLog.error(error, "Message delete failed") }
        }
    }

    func report(_ message: ChatMessage, in groupID: String, by uid: String) throws {
        guard let db else { throw ChatError.unavailable }
        db.collection("reports").addDocument(data: [
            "groupId": groupID,
            "messageId": message.id,
            "authorId": message.authorID,
            "text": message.text,
            "reportedBy": uid,
            "createdAt": FieldValue.serverTimestamp(),
        ]) { error in
            if let error { AppLog.error(error, "Report failed") }
        }
    }

    func newMessageID(in groupID: String) -> String {
        guard let db else { return UUID().uuidString }
        return messages(db, groupID).document().documentID
    }

    private static func page(from snapshot: QuerySnapshot, limit: Int) -> FeedPage<ChatMessage> {
        FeedPage(
            items: snapshot.documents.reversed().compactMap(message(from:)),
            isFull: snapshot.documents.count >= limit,
            isFromCache: snapshot.metadata.isFromCache
        )
    }

    private static func message(from document: QueryDocumentSnapshot) -> ChatMessage? {
        // Estimated, so a message sent offline sorts and shows as "now".
        var data = document.data(with: .estimate)
        for key in [ChatMessage.Field.createdAt, ChatMessage.Field.deletedAt] {
            if let timestamp = data[key] as? Timestamp { data[key] = timestamp.dateValue() }
        }
        // Without estimates, a server timestamp the server hasn't set yet reads as null.
        let isUnsent = document.metadata.hasPendingWrites && !(document.data()[ChatMessage.Field.createdAt] is Timestamp)
        return ChatMessage(id: document.documentID, firestoreData: data, isPending: isUnsent)
    }
}
