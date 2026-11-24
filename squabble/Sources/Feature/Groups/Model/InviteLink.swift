import Foundation

/// A squabble's invite link, `https://squabble-9c1df.web.app/join/<code>`: a universal link
/// served by Firebase Hosting (docs/specs/groups.md). The code is the server's; the app only
/// builds and reads links.
nonisolated enum InviteLink {
    static let host = "squabble-9c1df.web.app"

    static func url(code: String) -> URL? {
        guard isValid(code) else { return nil }
        return URL(string: "https://\(host)/join/\(code)")
    }

    /// The link as shown to people: without the scheme.
    static func displayText(for url: URL) -> String {
        (url.host() ?? "") + url.path()
    }

    /// The code in a link the app was opened with, or nil for anything else.
    static func code(from url: URL) -> String? {
        guard url.scheme == "https", url.host() == host else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "join", isValid(parts[1]) else { return nil }
        return parts[1]
    }

    private static func isValid(_ code: String) -> Bool {
        (8...64).contains(code.count) && code.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}
