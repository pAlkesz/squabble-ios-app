import Foundation

nonisolated enum GroupError: LocalizedError, Equatable {
    case invalidName
    case notSignedIn
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidName:
            String(localized: "Give the squabble a name, 50 characters at most.")
        case .notSignedIn:
            String(localized: "You're not signed in.")
        case .unavailable:
            String(localized: "Squabbles aren't available in this build.")
        }
    }
}
