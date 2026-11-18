import Foundation

/// What the add-by-handle field on the new-squabble screen says under itself.
nonisolated enum MemberLookup: Equatable {
    case idle
    case searching
    case invalid(HandleError)
    case notFound(Handle)
    case isYou
    case alreadyAdded(String)
    case full
    case offline
    case failed

    var message: String? {
        switch self {
        case .idle, .searching:
            nil
        case .invalid(let error):
            error.localizedDescription
        case .notFound(let handle):
            String(localized: "Nobody goes by \(handle.description). Check the spelling?", comment: "New squabble: no user holds the typed handle.")
        case .isYou:
            String(localized: "That's you. You're in this one whether you like it or not.", comment: "New squabble: the user typed their own handle.")
        case .alreadyAdded(let name):
            String(localized: "\(name) is already in.", comment: "New squabble: the person is already a member. The argument is their name.")
        case .full:
            String(localized: "\(SquabbleGroup.maxMembers) people max. That's a crowd, not a squabble.", comment: "New squabble: the member limit is reached.")
        case .offline:
            String(localized: "You're offline. Finding people needs the internet.", comment: "New squabble: handle lookup while offline.")
        case .failed:
            String(localized: "Couldn't look that up. Try again.", comment: "New squabble: handle lookup failed for another reason.")
        }
    }
}
