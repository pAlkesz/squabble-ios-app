import FirebaseCore
import FirebaseFirestore

/// Layout: `users/{uid}` (profile, readable by any signed-in user), `handles/{handle}`
/// (`{ uid }`, the uniqueness lock) and `users/{uid}/private/payment` (owner-only).
/// `firestore.rules` enforces the same shape.
nonisolated final class FirestoreProfileRepository: ProfileRepository {
    private var db: Firestore? {
        FirebaseApp.app() == nil ? nil : Firestore.firestore()
    }

    func profileChanges(for uid: String) -> AsyncThrowingStream<UserProfile?, Error> {
        guard let db else {
            return AsyncThrowingStream { $0.finish(throwing: ProfileError.unavailable) }
        }
        let reference = Self.user(uid, in: db)
        return AsyncThrowingStream { continuation in
            // Metadata changes are needed to hear the server confirm a cache miss.
            nonisolated(unsafe) let registration = reference.addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                if let error {
                    continuation.finish(throwing: Self.mapped(error))
                    return
                }
                guard let snapshot else { return }
                guard snapshot.exists else {
                    if !snapshot.metadata.isFromCache { continuation.yield(nil) }
                    return
                }
                do {
                    continuation.yield(try UserProfile(id: uid, firestoreData: snapshot.data() ?? [:]))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func isHandleAvailable(_ handle: Handle, for uid: String) async throws -> Bool {
        guard let db else { throw ProfileError.unavailable }
        do {
            let snapshot = try await Self.handle(handle, in: db).getDocument(source: .server)
            return !snapshot.exists || snapshot.data()?["uid"] as? String == uid
        } catch {
            throw Self.mapped(error)
        }
    }

    func createProfile(_ profile: UserProfile, paymentMethods: [PaymentMethod]) async throws {
        guard let db else { throw ProfileError.unavailable }
        let userReference = Self.user(profile.id, in: db)
        let handleReference = Self.handle(profile.handle, in: db)
        let paymentReference = Self.payment(profile.id, in: db)
        let uid = profile.id
        nonisolated(unsafe) var profileData = profile.firestoreData
        profileData[UserProfile.Field.createdAt] = FieldValue.serverTimestamp()
        profileData[UserProfile.Field.updatedAt] = FieldValue.serverTimestamp()
        nonisolated(unsafe) let paymentData: [String: Any] = ["methods": paymentMethods.map(\.firestoreData)]

        do {
            _ = try await db.runTransaction { transaction, errorPointer in
                let claim: DocumentSnapshot
                do {
                    claim = try transaction.getDocument(handleReference)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                if claim.exists {
                    guard claim.data()?["uid"] as? String == uid else {
                        errorPointer?.pointee = ProfileError.handleTaken as NSError
                        return nil
                    }
                } else {
                    transaction.setData(["uid": uid], forDocument: handleReference)
                }
                transaction.setData(profileData, forDocument: userReference)
                transaction.setData(paymentData, forDocument: paymentReference)
                return nil
            }
        } catch {
            throw Self.mapped(error)
        }
    }

    func deleteProfile(_ profile: UserProfile?, uid: String) async throws {
        guard let db else { throw ProfileError.unavailable }
        let batch = db.batch()
        batch.deleteDocument(Self.payment(uid, in: db))
        if let profile {
            batch.deleteDocument(Self.handle(profile.handle, in: db))
        }
        batch.deleteDocument(Self.user(uid, in: db))
        do {
            try await batch.commit()
        } catch {
            throw Self.mapped(error)
        }
    }

    private static func user(_ uid: String, in db: Firestore) -> DocumentReference {
        db.collection("users").document(uid)
    }

    private static func handle(_ handle: Handle, in db: Firestore) -> DocumentReference {
        db.collection("handles").document(handle.rawValue)
    }

    private static func payment(_ uid: String, in db: Firestore) -> DocumentReference {
        user(uid, in: db).collection("private").document("payment")
    }

    private static func mapped(_ error: Error) -> Error {
        if error is ProfileError { return error }
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain, nsError.code == FirestoreErrorCode.unavailable.rawValue {
            return ProfileError.offline
        }
        return error
    }
}
