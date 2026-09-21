import Foundation

nonisolated enum AuthError: LocalizedError {
    case missingIdentityToken
    case missingAuthorizationCode
    case notSignedIn
    case unavailable

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            String(localized: "Apple didn't return an identity token.")
        case .missingAuthorizationCode:
            String(localized: "Apple didn't return an authorization code.")
        case .notSignedIn:
            String(localized: "You're not signed in.")
        case .unavailable:
            String(localized: "Sign-in isn't available in this build.")
        }
    }
}
