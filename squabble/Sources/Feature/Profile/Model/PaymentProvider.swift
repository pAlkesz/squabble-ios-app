import Foundation

/// Payment-link services we're willing to show other people. Links are rebuilt from a
/// username rather than stored as free-form URLs, so a profile can never point someone
/// at an arbitrary site.
nonisolated enum PaymentProvider: String, CaseIterable, Sendable {
    case revolut
    case paypal
    case wise

    var name: String {
        switch self {
        case .revolut: "Revolut"
        case .paypal: "PayPal"
        case .wise: "Wise"
        }
    }

    /// Host plus path prefix, as users paste it.
    var linkPrefixes: [String] {
        switch self {
        case .revolut: ["revolut.me/"]
        case .paypal: ["paypal.me/", "paypal.com/paypalme/"]
        case .wise: ["wise.com/pay/me/"]
        }
    }

    func url(for username: String) -> URL? {
        URL(string: "https://\(linkPrefixes[0])\(username)")
    }
}
