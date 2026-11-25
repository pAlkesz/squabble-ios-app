import Foundation

/// An exact amount, held as it's stored: whole minor units (cents, whole forints) and a
/// currency code.
nonisolated struct Money: Equatable, Hashable, Sendable {
    let minorUnits: Int64
    let currencyCode: String

    init(minorUnits: Int64, currencyCode: String) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    /// Nil when the amount has more decimals than the currency, or doesn't fit. Never rounds:
    /// what to do with a stray decimal is the caller's decision.
    init?(amount: Decimal, currencyCode: String) {
        guard amount.isFinite else { return nil }
        let scaled = amount * pow(10, CurrencyPrecision.fractionDigits(for: currencyCode))
        // Within Int64 the conversion below is exact; outside it, it would wrap.
        guard scaled >= Decimal(Int64.min), scaled <= Decimal(Int64.max) else { return nil }
        let units = NSDecimalNumber(decimal: scaled).int64Value
        guard Decimal(units) == scaled else { return nil }
        self.init(minorUnits: units, currencyCode: currencyCode)
    }

    /// Rounded to the currency's precision, half away from zero; nil when it doesn't fit.
    init?(rounding amount: Decimal, currencyCode: String) {
        var exact = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &exact, CurrencyPrecision.fractionDigits(for: currencyCode), .plain)
        self.init(amount: rounded, currencyCode: currencyCode)
    }

    var amount: Decimal {
        Decimal(minorUnits) / pow(10, CurrencyPrecision.fractionDigits(for: currencyCode))
    }

    /// "+€12.00" for what you're owed, "−€12.00" for what you owe.
    func formattedWithSign(locale: Locale = .current) -> String {
        amount.formatted(
            .currency(code: currencyCode)
                .precision(.fractionLength(CurrencyPrecision.fractionDigits(for: currencyCode)))
                .sign(strategy: .always(showZero: false))
                .locale(locale)
        )
    }

    func formatted(locale: Locale = .current) -> String {
        amount.formatted(
            .currency(code: currencyCode)
                .precision(.fractionLength(CurrencyPrecision.fractionDigits(for: currencyCode)))
                .locale(locale)
        )
    }
}
