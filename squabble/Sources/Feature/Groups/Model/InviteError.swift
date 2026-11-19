import Foundation

nonisolated enum InviteError: Error, Equatable, LocalizedError {
    /// Unknown code, or one the creator has reset.
    case invalidLink
    case archived
    case full
    case needsInternet
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            String(localized: "This link doesn't work any more. Ask for a fresh one.", comment: "Invite error: the link is unknown or was reset.")
        case .archived:
            String(localized: "This squabble is archived, so nobody new can join.", comment: "Invite error: the squabble is archived.")
        case .full:
            String(localized: "This squabble is full. 50 people is plenty of drama.", comment: "Invite error: the squabble has 50 members.")
        case .needsInternet:
            String(localized: "Invites need an internet connection.", comment: "Invite error: offline.")
        case .unavailable:
            String(localized: "Couldn't reach Squabble. Try again in a moment.", comment: "Invite error: the server call failed.")
        }
    }
}
