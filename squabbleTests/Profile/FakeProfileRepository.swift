import Foundation
@testable import squabble

/// In-memory profile store. `profileChanges` behaves like the Firestore listener: it
/// emits the current value, then every later write, until cancelled.
nonisolated final class FakeProfileRepository: ProfileRepository, @unchecked Sendable {
    private(set) var profiles: [String: UserProfile] = [:]
    private(set) var paymentMethods: [String: [PaymentMethod]] = [:]
    private(set) var claimedHandles: [Handle: String] = [:]
    private(set) var deletedUIDs: [String] = []
    var listenerError: Error?
    var saveError: Error?
    private var continuations: [String: [AsyncThrowingStream<UserProfile?, Error>.Continuation]] = [:]

    func seed(_ profile: UserProfile) {
        profiles[profile.id] = profile
        claimedHandles[profile.handle] = profile.id
    }

    func claim(_ handle: Handle, by uid: String) {
        claimedHandles[handle] = uid
    }

    func profileChanges(for uid: String) -> AsyncThrowingStream<UserProfile?, Error> {
        AsyncThrowingStream { continuation in
            if let listenerError {
                continuation.finish(throwing: listenerError)
                return
            }
            continuations[uid, default: []].append(continuation)
            continuation.yield(profiles[uid])
        }
    }

    func isHandleAvailable(_ handle: Handle, for uid: String) async throws -> Bool {
        claimedHandles[handle].map { $0 == uid } ?? true
    }

    func createProfile(_ profile: UserProfile, paymentMethods: [PaymentMethod]) async throws {
        if let saveError { throw saveError }
        if let owner = claimedHandles[profile.handle], owner != profile.id { throw ProfileError.handleTaken }
        claimedHandles[profile.handle] = profile.id
        profiles[profile.id] = profile
        self.paymentMethods[profile.id] = paymentMethods
        publish(profile.id)
    }

    func deleteProfile(_ profile: UserProfile?, uid: String) async throws {
        deletedUIDs.append(uid)
        if let profile { claimedHandles[profile.handle] = nil }
        profiles[uid] = nil
        paymentMethods[uid] = nil
        publish(uid)
    }

    private func publish(_ uid: String) {
        continuations[uid]?.forEach { $0.yield(profiles[uid]) }
    }
}
