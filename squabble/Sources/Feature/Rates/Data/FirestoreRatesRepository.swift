import FirebaseCore
import FirebaseFirestore

nonisolated final class FirestoreRatesRepository: RatesRepository {
    private var db: Firestore? {
        FirebaseApp.app() == nil ? nil : Firestore.firestore()
    }

    func latestRates() -> AsyncThrowingStream<ExchangeRates?, Error> {
        guard let db else { return AsyncThrowingStream { $0.finish() } }
        return AsyncThrowingStream { continuation in
            nonisolated(unsafe) let registration = db.document("rates/latest").addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                continuation.yield(snapshot?.data().flatMap(ExchangeRates.init(firestoreData:)))
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }
}
