import Foundation

/// One printed row of the prop receipt on the welcome screen.
nonisolated enum ReceiptRow {
    case header(String)
    case subheader(String)
    case rule
    case item(label: String, amount: String)
    case note(String)
    case total(label: String, amount: String)
    case footer(String)
}

/// The welcome receipt: the app's features itemised as a bill, every one of them free,
/// with the joke landing on the total. Denominated in euros on purpose — a prop, and the
/// reader's own currency would make the amounts read as real money.
nonisolated enum WelcomeReceipt {
    static var rows: [ReceiptRow] {
        [
            .header(String(localized: "SQUABBLE")),
            .subheader(String(localized: "OPEN TAB · 3 GUESTS")),
            .rule,
            .item(label: String(localized: "Split any bill"), amount: money(0)),
            .item(label: String(localized: "Scan the receipt"), amount: money(0)),
            .item(label: String(localized: "Who owes what"), amount: money(0)),
            .item(label: String(localized: "Petty reminders"), amount: money(0)),
            .note(String(localized: "we'll phrase it nicely")),
            .rule,
            .total(label: String(localized: "TOTAL"), amount: String(localized: "friendship")),
            .rule,
            .footer(String(localized: "FREE. THE FALLOUT ISN'T.")),
        ]
    }

    private static func money(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "EUR"))
    }
}
