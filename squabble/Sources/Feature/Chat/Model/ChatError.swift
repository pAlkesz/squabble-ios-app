import Foundation

nonisolated enum ChatError: Error, LocalizedError {
    case unavailable

    var errorDescription: String? {
        String(localized: "The chat isn't loading. Try again in a moment.", comment: "Chat error: the messages couldn't be loaded.")
    }
}
