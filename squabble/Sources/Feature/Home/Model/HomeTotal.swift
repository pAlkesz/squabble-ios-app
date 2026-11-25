/// The user's balance across every squabble. Nothing converts yet, so only squabbles in the
/// home currency make up the headline; the rest are added up per currency beside it.
nonisolated struct HomeTotal: Equatable, Sendable {
    let home: Money
    /// Never zero; by currency code.
    let others: [Money]

    init(groups: [SquabbleGroup], uid: String, homeCurrencyCode: String) {
        var totals: [String: Int64] = [:]
        for group in groups {
            let (sum, overflow) = (totals[group.currencyCode] ?? 0)
                .addingReportingOverflow(group.balance(of: uid).minorUnits)
            if !overflow { totals[group.currencyCode] = sum }
        }
        home = Money(minorUnits: totals[homeCurrencyCode] ?? 0, currencyCode: homeCurrencyCode)
        others = totals
            .filter { $0.key != homeCurrencyCode && $0.value != 0 }
            .map { Money(minorUnits: $0.value, currencyCode: $0.key) }
            .sorted { $0.currencyCode < $1.currencyCode }
    }
}
