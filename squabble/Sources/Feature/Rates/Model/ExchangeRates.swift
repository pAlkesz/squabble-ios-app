import Foundation

/// The ECB's reference rates of one day, for showing amounts in another currency. Never for
/// what somebody owes: that stays in the squabble's own currency (docs/specs/bills.md).
nonisolated struct ExchangeRates: Equatable, Sendable {
    /// The day they were published for, yyyy-MM-dd.
    let date: String
    private let unitsPerEuro: [String: Decimal]

    init(date: String, unitsPerEuro: [String: Decimal]) {
        self.date = date
        self.unitsPerEuro = unitsPerEuro.filter { $0.value.isFinite && $0.value > 0 }
            .merging(["EUR": 1]) { $1 }
    }

    /// Nil when the ECB doesn't publish a rate.
    func unitsPerEuro(of currencyCode: String) -> Decimal? {
        unitsPerEuro[currencyCode]
    }

    /// Unrounded, so several can be added up before rounding once.
    func amount(of money: Money, in currencyCode: String) -> Decimal? {
        if money.currencyCode == currencyCode { return money.amount }
        guard let from = unitsPerEuro[money.currencyCode], let to = unitsPerEuro[currencyCode] else { return nil }
        return money.amount * to / from
    }
}
