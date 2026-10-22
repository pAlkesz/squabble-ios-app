import FirebaseCore
import FirebaseFirestore

/// Layout: `users/{uid}` (profile, readable by any signed-in user), `handles/{handle}`
/// (`{ uid }`, the uniqueness lock), and the owner-only `users/{uid}/private/payment` and
/// `users/{uid}/private/preferences`.
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
            // Offline, the listener never errors on a cache miss — it just waits for the
            // server indefinitely. A one-off server read fails fast instead, so "we can't
            // tell yet" becomes an error the UI can offer a retry for.
            nonisolated(unsafe) var serverCheck: Task<Void, Never>?
            // Metadata changes are needed to hear the server confirm a cache miss.
            nonisolated(unsafe) let registration = reference.addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                if let error {
                    continuation.finish(throwing: Self.mapped(error))
                    return
                }
                guard let snapshot else { return }
                guard snapshot.exists else {
                    if !snapshot.metadata.isFromCache {
                        continuation.yield(nil)
                    } else if serverCheck == nil {
                        serverCheck = Task {
                            do {
                                let server = try await reference.getDocument(source: .server)
                                if !server.exists { continuation.yield(nil) }
                            } catch {
                                continuation.finish(throwing: Self.mapped(error))
                            }
                        }
                    }
                    return
                }
                do {
                    continuation.yield(try UserProfile(id: uid, firestoreData: snapshot.data() ?? [:]))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                registration.remove()
                serverCheck?.cancel()
            }
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

    func updateProfile(_ profile: UserProfile) throws {
        guard let db else { throw ProfileError.unavailable }
        Self.user(profile.id, in: db).updateData([
            UserProfile.Field.displayName: profile.displayName,
            UserProfile.Field.avatar: profile.avatar.firestoreData,
            UserProfile.Field.updatedAt: FieldValue.serverTimestamp(),
        ], completion: Self.logFailure("Profile update failed"))
    }

    func paymentMethodChanges(for uid: String) -> AsyncThrowingStream<[PaymentMethod], Error> {
        guard let db else {
            return AsyncThrowingStream { $0.finish(throwing: ProfileError.unavailable) }
        }
        return Self.changes(of: Self.payment(uid, in: db)) { data in
            let entries = data["methods"] as? [[String: Any]] ?? []
            return entries.compactMap(PaymentMethod.init(firestoreData:))
        }
    }

    func setPaymentMethods(_ methods: [PaymentMethod], for uid: String) throws {
        guard let db else { throw ProfileError.unavailable }
        Self.payment(uid, in: db).setData(
            ["methods": methods.map(\.firestoreData)],
            completion: Self.logFailure("Payment methods update failed")
        )
    }

    func preferenceChanges(for uid: String) -> AsyncThrowingStream<UserPreferences, Error> {
        guard let db else {
            return AsyncThrowingStream { $0.finish(throwing: ProfileError.unavailable) }
        }
        return Self.changes(of: Self.preferences(uid, in: db), map: UserPreferences.init(firestoreData:))
    }

    func setPreferences(_ preferences: UserPreferences, for uid: String) throws {
        guard let db else { throw ProfileError.unavailable }
        Self.preferences(uid, in: db).setData(
            preferences.firestoreData,
            completion: Self.logFailure("Preferences update failed")
        )
    }

    func deleteProfile(_ profile: UserProfile?, uid: String) async throws {
        guard let db else { throw ProfileError.unavailable }
        let batch = db.batch()
        batch.deleteDocument(Self.payment(uid, in: db))
        batch.deleteDocument(Self.preferences(uid, in: db))
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

    private static func preferences(_ uid: String, in db: Firestore) -> DocumentReference {
        user(uid, in: db).collection("private").document("preferences")
    }

    /// A missing document reads as empty data: these documents only appear on first save.
    /// The cache answers first, so an owner-only page shows up offline too.
    private static func changes<Value: Sendable>(
        of reference: DocumentReference,
        map: @escaping @Sendable ([String: Any]) -> Value
    ) -> AsyncThrowingStream<Value, Error> {
        AsyncThrowingStream { continuation in
            nonisolated(unsafe) let registration = reference.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: mapped(error))
                    return
                }
                guard let snapshot else { return }
                continuation.yield(map(snapshot.data() ?? [:]))
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    /// Writes go to the local cache and sync later, so nothing waits for the server; a
    /// rejection only shows up here, long after the screen has moved on.
    private static func logFailure(_ context: String) -> @Sendable (Error?) -> Void {
        { error in
            if let error { AppLog.error(error, context) }
        }
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
