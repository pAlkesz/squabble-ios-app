import Foundation

nonisolated struct PaymentLink: Hashable, Sendable {
    static let usernameLengthRange = 2...40

    let provider: PaymentProvider
    let username: String

    /// Accepts a bare username, `@username`, or a pasted link for that provider
    /// (`https://revolut.me/pal`). Anything after the username — like a PayPal.me
    /// amount — is dropped.
    init(provider: PaymentProvider, input: String) throws(PaymentLinkError) {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        for scheme in ["https://", "http://"] where value.lowercased().hasPrefix(scheme) {
            value.removeFirst(scheme.count)
        }
        if value.lowercased().hasPrefix("www.") { value.removeFirst(4) }
        if let prefix = provider.linkPrefixes.first(where: { value.lowercased().hasPrefix($0) }) {
            value.removeFirst(prefix.count)
        } else if value.contains("/") {
            throw .wrongProvider
        }
        if value.hasPrefix("@") { value.removeFirst() }
        let username = value.split(separator: "/", maxSplits: 1).first.map(String.init) ?? ""

        guard Self.usernameLengthRange.contains(username.count),
              username.unicodeScalars.allSatisfy(Self.isAllowed)
        else { throw .invalidUsername }
        self.provider = provider
        self.username = username
    }

    var url: URL? { provider.url(for: username) }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) || ("0"..."9").contains(scalar)
            || scalar == "_" || scalar == "-" || scalar == "."
    }
}

nonisolated enum PaymentLinkError: LocalizedError, Equatable {
    case invalidUsername
    case wrongProvider

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            String(localized: "That doesn't look like a username.")
        case .wrongProvider:
            String(localized: "That link is for a different service.")
        }
    }
}
