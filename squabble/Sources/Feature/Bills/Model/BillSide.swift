import Foundation

/// How a bill looks from one person's side.
nonisolated enum BillSide: Equatable {
    case youOwe(to: String, Money)
    case owedToYou(Money)
    /// On it, but it changes nothing (paid for only themselves).
    case even(Money)
    case notInvolved(Money)

    init(bill: Bill, uid: String?) {
        guard let uid, bill.involves(uid) else {
            self = .notInvolved(bill.total)
            return
        }
        let effect = bill.effect(on: uid)
        if effect.minorUnits < 0 {
            self = .youOwe(to: bill.paidBy, Money(minorUnits: -effect.minorUnits, currencyCode: effect.currencyCode))
        } else if effect.minorUnits > 0 {
            self = .owedToYou(effect)
        } else {
            self = .even(bill.total)
        }
    }

    var amount: Money {
        switch self {
        case .youOwe(_, let money), .owedToYou(let money), .even(let money), .notInvolved(let money): money
        }
    }
}
