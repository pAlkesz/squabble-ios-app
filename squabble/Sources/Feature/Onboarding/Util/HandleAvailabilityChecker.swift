/// Validates a typed handle and asks the server whether it's free.
nonisolated struct HandleAvailabilityChecker {
    let profiles: ProfileRepository
    var logFailure: @Sendable (Error) -> Void = { AppLog.error($0, "Handle availability check failed") }

    /// What can be settled without the server: empty or invalid input, or no connection.
    /// Nil means the server has to be asked.
    static func preflight(_ input: String, isOnline: Bool) -> HandleAvailability? {
        guard !input.isEmpty else { return .idle }
        do {
            _ = try Handle(validating: input)
        } catch {
            return .invalid(error)
        }
        return isOnline ? nil : .offline
    }

    func check(_ input: String, for uid: String, isOnline: Bool) async -> HandleAvailability {
        if let verdict = Self.preflight(input, isOnline: isOnline) { return verdict }
        do {
            let handle = try Handle(validating: input)
            return try await profiles.isHandleAvailable(handle, for: uid) ? .available : .taken
        } catch ProfileError.offline {
            return .offline
        } catch {
            logFailure(error)
            return .failed
        }
    }
}
