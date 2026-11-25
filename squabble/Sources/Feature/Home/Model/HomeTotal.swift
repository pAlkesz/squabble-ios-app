import Foundation

/// The user's balance across every squabble, in the home currency. Balances in other
/// currencies are converted at the latest rates; one without a rate is shown beside the
/// headline rather than guessed. Display only: nobody owes this number.
nonisolated struct HomeTotal: Equatable, Sendable {
    let headline: Money
    /// What couldn't be converted. Never zero; by currency code.
    let others: [Money]

    init(groups: [SquabbleGroup], uid: String, homeCurrencyCode: String, rates: ExchangeRates?) {
        var totals: [String: Int64] = [:]
        for group in groups {
            let (sum, overflow) = (totals[group.currencyCode] ?? 0)
                .addingReportingOverflow(group.balance(of: uid).minorUnits)
            if !overflow { totals[group.currencyCode] = sum }
        }
        let home = Money(minorUnits: totals[homeCurrencyCode] ?? 0, currencyCode: homeCurrencyCode)
        let foreign = totals
            .filter { $0.key != homeCurrencyCode && $0.value != 0 }
            .map { Money(minorUnits: $0.value, currencyCode: $0.key) }
            .sorted { $0.currencyCode < $1.currencyCode }

        // Added up before rounding, so each currency doesn't bring its own rounding error.
        let converted = foreign.compactMap { rates?.amount(of: $0, in: homeCurrencyCode) }
        if !converted.isEmpty, let sum = Money(rounding: converted.reduce(home.amount, +), currencyCode: homeCurrencyCode) {
            headline = sum
            others = foreign.filter { rates?.amount(of: $0, in: homeCurrencyCode) == nil }
        } else if home.minorUnits == 0, foreign.count == 1, let only = foreign.first {
            // Better than a zero.
            headline = only
            others = []
        } else {
            headline = home
            others = foreign
        }
    }
}
