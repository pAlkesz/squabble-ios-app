import Foundation

nonisolated enum GroupError: LocalizedError, Equatable {
    case invalidName
    case notSignedIn
    case unavailable
    case photoNeedsInternet

    var errorDescription: String? {
        switch self {
        case .invalidName:
            String(localized: "Give the squabble a name, 50 characters at most.")
        case .notSignedIn:
            String(localized: "You're not signed in.")
        case .unavailable:
            String(localized: "Squabbles aren't available in this build.")
        case .photoNeedsInternet:
            String(localized: "You're offline, and the photo needs the internet. Remove it to create the squabble now, or try again when you're back.")
        }
    }
}
