import Foundation

nonisolated enum ProfileError: LocalizedError, Equatable {
    case handleTaken
    case offline
    case invalidImage
    case unavailable

    var errorDescription: String? {
        switch self {
        case .handleTaken:
            String(localized: "Someone already took that handle. Pick another one.")
        case .offline:
            String(localized: "You're offline. This part needs the internet — try again when you're back.")
        case .invalidImage:
            String(localized: "That picture didn't work. Try a different one.")
        case .unavailable:
            String(localized: "Profiles aren't available in this build.")
        }
    }
}
