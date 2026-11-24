import Foundation

/// A squabble's invite link, `https://squabble-club.web.app/join/<code>`: a universal link
/// served by Firebase Hosting (docs/specs/groups.md). The code is the server's; the app only
/// builds and reads links.
nonisolated enum InviteLink {
    static let host = "squabble-club.web.app"
    /// Links shared before the nicer address (Nov 2026) keep working.
    private static let formerHost = "squabble-9c1df.web.app"

    static func url(code: String) -> URL? {
        guard isValid(code) else { return nil }
        return URL(string: "https://\(host)/join/\(code)")
    }

    /// The link as shown to people: the address and just the end of the code.
    static func displayText(code: String) -> String? {
        guard isValid(code) else { return nil }
        return "https://\(host)/…\(code.suffix(4))"
    }

    /// The code in a link the app was opened with, or nil for anything else.
    static func code(from url: URL) -> String? {
        guard url.scheme == "https", let linkHost = url.host(), [host, formerHost].contains(linkHost) else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "join", isValid(parts[1]) else { return nil }
        return parts[1]
    }

    private static func isValid(_ code: String) -> Bool {
        (8...64).contains(code.count) && code.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}
