import Foundation

/// Names and phrases shared by the bill views.
enum BillText {
    static func name(of uid: String, in group: SquabbleGroup) -> String {
        ChatMessageRow.name(of: group.members[uid])
    }

    /// For lists and rows, where "You" reads better than your own name.
    static func name(of uid: String, in group: SquabbleGroup, me: String?) -> String {
        uid == me
            ? String(localized: "You", comment: "Squabble page: tag on the user's own row.")
            : name(of: uid, in: group)
    }

    /// The same inside a phrase ("Paid by you").
    static func nameInPhrase(of uid: String, in group: SquabbleGroup, me: String?) -> String {
        uid == me
            ? String(localized: "you", comment: "Bill details: the user, inside a phrase like 'Paid by you'.")
            : name(of: uid, in: group)
    }

    static func avatar(of uid: String, in group: SquabbleGroup) -> Avatar {
        group.members[uid]?.avatar ?? .preset(.default(for: uid))
    }

    static func standing(_ balance: Money) -> String {
        if balance.minorUnits < 0 {
            let owed = Money(minorUnits: -balance.minorUnits, currencyCode: balance.currencyCode)
            return String(localized: "You owe \(owed.formatted())", comment: "The user's balance in a squabble: what they owe altogether.")
        }
        if balance.minorUnits > 0 {
            return String(localized: "You're owed \(balance.formatted())", comment: "The user's balance in a squabble: what they're owed altogether.")
        }
        return String(localized: "You're settled up", comment: "The user's balance in a squabble: exactly zero.")
    }

    static func day(_ day: CalendarDay) -> String {
        ChatTimeline.dayTitle(for: Calendar.current.startOfDay(for: day.date()))
    }
}

extension BillSide {
    func title(in group: SquabbleGroup) -> String {
        switch self {
        case .youOwe(let payer, _):
            String(localized: "You owe \(BillText.name(of: payer, in: group))", comment: "Bill in the chat: the user owes the person who paid.")
        case .owedToYou:
            String(localized: "You're owed", comment: "Bill in the chat: the user paid for others; the amount follows.")
        case .even:
            String(localized: "All yours", comment: "Bill in the chat: the user paid only for themselves.")
        case .notInvolved:
            String(localized: "You're not in this one", comment: "Bill in the chat: the user neither paid nor shares it.")
        }
    }
}
