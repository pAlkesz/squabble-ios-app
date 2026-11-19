import FirebaseCore
import FirebaseFunctions
import Foundation

nonisolated final class FirebaseInviteRepository: InviteRepository {
    private var functions: Functions? {
        FirebaseApp.app() == nil ? nil : Functions.functions()
    }

    func inviteCode(for groupID: String) async throws(InviteError) -> String {
        try code(in: await call("createInvite", ["groupId": groupID]))
    }

    func resetInvite(for groupID: String) async throws(InviteError) -> String {
        try code(in: await call("resetInvite", ["groupId": groupID]))
    }

    func preview(code: String) async throws(InviteError) -> InvitePreview {
        let data = try await call("previewInvite", ["code": code])
        guard let groupID = data["groupId"] as? String, let name = data["name"] as? String else {
            throw .unavailable
        }
        return InvitePreview(
            groupID: groupID,
            name: name,
            image: (data["image"] as? [String: Any]).flatMap(SquabbleImage.init(firestoreData:)) ?? .default(for: groupID),
            memberCount: data["memberCount"] as? Int ?? 0,
            isMember: data["isMember"] as? Bool ?? false,
            isArchived: data["isArchived"] as? Bool ?? false
        )
    }

    func join(code: String) async throws(InviteError) -> String {
        guard let groupID = try await call("joinGroup", ["code": code])["groupId"] as? String else {
            throw .unavailable
        }
        return groupID
    }

    private func code(in data: [String: Any]) throws(InviteError) -> String {
        guard let code = data["code"] as? String else { throw .unavailable }
        return code
    }

    private func call(_ name: String, _ payload: [String: String]) async throws(InviteError) -> [String: Any] {
        guard let functions else { throw .unavailable }
        do {
            let result = try await functions.httpsCallable(name).call(payload)
            return result.data as? [String: Any] ?? [:]
        } catch {
            throw Self.inviteError(for: error)
        }
    }

    private static func inviteError(for error: any Error) -> InviteError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return .needsInternet }
        guard nsError.domain == FunctionsErrorDomain, let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .unavailable
        }
        switch code {
        case .notFound: return .invalidLink
        case .resourceExhausted: return .full
        case .failedPrecondition: return nsError.localizedDescription == "archived" ? .archived : .unavailable
        case .unavailable, .deadlineExceeded: return .needsInternet
        default: return .unavailable
        }
    }
}
