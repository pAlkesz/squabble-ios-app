/// Validates a typed handle and asks the server whether it's free.
nonisolated struct HandleAvailabilityChecker {
    let profiles: ProfileRepository
    var logFailure: @Sendable (Error) -> Void = { AppLog.error($0, "Handle availability check failed") }

    /// What can be settled without the server: invalid (including empty) input, or no
    /// connection. Nil means the server has to be asked.
    static func preflight(_ input: String, isOnline: Bool) -> HandleAvailability? {
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

    /// The free ones among `candidates`, at most `limit`, in the given order. A failed
    /// lookup just means one suggestion fewer.
    func freeHandles(among candidates: [Handle], uid: String, limit: Int) async -> [Handle] {
        let free = await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask {
                    (index, (try? await profiles.isHandleAvailable(candidate, for: uid)) == true)
                }
            }
            var free: Set<Int> = []
            for await (index, isFree) in group where isFree {
                free.insert(index)
            }
            return free
        }
        return candidates.indices
            .filter(free.contains)
            .prefix(limit)
            .map { candidates[$0] }
    }
}
