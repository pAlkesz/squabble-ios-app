import FirebaseCore
import FirebaseFirestore

/// `groups/{gid}/bills`; `firestore.rules` enforces the shape, and the `updateBalances`
/// function keeps the group's balances in step.
nonisolated final class FirestoreBillRepository: BillRepository {
    private var db: Firestore? {
        FirebaseApp.app() == nil ? nil : Firestore.firestore()
    }

    private func bills(_ db: Firestore, _ groupID: String) -> CollectionReference {
        db.collection("groups").document(groupID).collection("bills")
    }

    func latestBills(in groupID: String, limit: Int) -> AsyncThrowingStream<FeedPage<Bill>, Error> {
        guard let db else {
            return AsyncThrowingStream { $0.finish(throwing: GroupError.unavailable) }
        }
        let query = bills(db, groupID).order(by: Bill.Field.createdAt, descending: true).limit(to: limit)
        return AsyncThrowingStream { continuation in
            // Metadata changes too, so "not sent yet" clears once the server has a bill.
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

    func bills(in groupID: String, before date: Date, limit: Int) async throws -> FeedPage<Bill> {
        guard let db else { throw GroupError.unavailable }
        let snapshot = try await bills(db, groupID)
            .order(by: Bill.Field.createdAt, descending: true)
            .whereField(Bill.Field.createdAt, isLessThan: Timestamp(date: date))
            .limit(to: limit)
            .getDocuments()
        return Self.page(from: snapshot, limit: limit)
    }

    func add(_ bill: Bill, in groupID: String) throws {
        var data = bill.firestoreData
        data[Bill.Field.createdAt] = FieldValue.serverTimestamp()
        data[Bill.Field.updatedAt] = FieldValue.serverTimestamp()
        try write(in: groupID, activity: .bill(.billAdded, bill, by: bill.createdBy), "Adding a bill failed") { batch, bills in
            batch.setData(data, forDocument: bills.document(bill.id))
        }
    }

    func update(_ bill: Bill, in groupID: String) throws {
        var data = bill.editableFirestoreData
        data[Bill.Field.updatedAt] = FieldValue.serverTimestamp()
        try write(in: groupID, activity: .bill(.billEdited, bill, by: bill.updatedBy), "Editing a bill failed") { batch, bills in
            batch.updateData(data, forDocument: bills.document(bill.id))
        }
    }

    func delete(_ bill: Bill, by uid: String, in groupID: String) throws {
        try write(in: groupID, activity: .bill(.billDeleted, bill, by: uid), "Deleting a bill failed") { batch, bills in
            batch.updateData([
                Bill.Field.deletedAt: FieldValue.serverTimestamp(),
                Bill.Field.updatedBy: uid,
                Bill.Field.updatedAt: FieldValue.serverTimestamp(),
            ], forDocument: bills.document(bill.id))
        }
    }

    private func write(
        in groupID: String,
        activity: SquabbleActivity,
        _ context: String,
        _ change: (WriteBatch, CollectionReference) -> Void
    ) throws {
        guard let db else { throw GroupError.unavailable }
        let batch = db.batch()
        change(batch, bills(db, groupID))
        batch.updateData(
            [
                SquabbleGroup.Field.updatedAt: FieldValue.serverTimestamp(),
                SquabbleGroup.Field.lastActivity: activity.firestoreData,
            ],
            forDocument: db.collection("groups").document(groupID)
        )
        batch.commit { error in
            if let error { AppLog.error(error, context) }
        }
    }

    private static func page(from snapshot: QuerySnapshot, limit: Int) -> FeedPage<Bill> {
        FeedPage(
            items: snapshot.documents.reversed().compactMap(bill(from:)),
            isFull: snapshot.documents.count >= limit,
            isFromCache: snapshot.metadata.isFromCache
        )
    }

    private static func bill(from document: QueryDocumentSnapshot) -> Bill? {
        // Estimated, so a bill added offline sorts and shows as "now".
        var data = document.data(with: .estimate)
        for key in [Bill.Field.createdAt, Bill.Field.updatedAt, Bill.Field.deletedAt] {
            if let timestamp = data[key] as? Timestamp { data[key] = timestamp.dateValue() }
        }
        return Bill(id: document.documentID, firestoreData: data, isPending: document.metadata.hasPendingWrites)
    }
}
