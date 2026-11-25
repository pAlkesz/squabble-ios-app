/// The user's balance across every squabble. Nothing converts yet, so only squabbles in the
/// one currency make up the headline; the rest are added up per currency beside it. That's
/// the home currency, unless nothing is owed in it and the only balance is in another.
nonisolated struct HomeTotal: Equatable, Sendable {
    let headline: Money
    /// Never zero; by currency code.
    let others: [Money]

    init(groups: [SquabbleGroup], uid: String, homeCurrencyCode: String) {
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
        if home.minorUnits == 0, foreign.count == 1, let only = foreign.first {
            headline = only
            others = []
        } else {
            headline = home
            others = foreign
        }
    }
}
