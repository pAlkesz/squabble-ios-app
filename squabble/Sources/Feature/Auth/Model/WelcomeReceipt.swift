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

/// The joke receipt: a bill nobody would ever agree on, printed before the user has
/// even signed in. Denominated in euros on purpose — it's a prop from a fictional
/// restaurant, and the reader's own currency makes the amounts read as real money.
nonisolated enum WelcomeReceipt {
    static var rows: [ReceiptRow] {
        [
            .header(String(localized: "SQUABBLE")),
            .subheader(String(localized: "TABLE 4 · 3 GUESTS")),
            .rule,
            .item(label: String(localized: "Nachos"), amount: money(4)),
            .note(String(localized: "you had one")),
            .item(label: String(localized: "Dave's 3rd beer"), amount: money(7.5)),
            .item(label: String(localized: "\"Next one's on me\""), amount: money(0)),
            .item(label: String(localized: "Emotional damage"), amount: "???"),
            .rule,
            .total(label: String(localized: "TOTAL"), amount: String(localized: "friendship")),
            .rule,
            .footer(String(localized: "NO REFUNDS · NO MERCY")),
        ]
    }

    private static func money(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "EUR"))
    }
}
