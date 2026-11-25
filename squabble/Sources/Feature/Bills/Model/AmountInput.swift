import Foundation

/// Typed amounts, kept in the reader's own number format and turned into exact minor units.
nonisolated enum AmountInput {
    /// Drops whatever can't be part of an amount in this currency. Either separator counts as
    /// the decimal one, since keyboards and pasted text don't always match the region.
    static func sanitized(_ input: String, currencyCode: String, locale: Locale = .current) -> String {
        let digits = CurrencyPrecision.fractionDigits(for: currencyCode)
        let separator = locale.decimalSeparator ?? "."
        var whole = "", fraction = "", hasSeparator = false
        for character in input {
            if let value = character.wholeNumberValue, (0...9).contains(value) {
                if !hasSeparator {
                    whole += String(value)
                } else if fraction.count < digits {
                    fraction += String(value)
                }
            } else if character == "." || character == "," || String(character) == separator {
                if digits > 0 { hasSeparator = true }
            }
        }
        whole = String(whole.drop { $0 == "0" }.prefix(12))
        if whole.isEmpty, hasSeparator || input.contains(where: { $0.wholeNumberValue == 0 }) { whole = "0" }
        return hasSeparator ? whole + separator + fraction : whole
    }

    /// Nil when there's nothing to read yet.
    static func money(from text: String, currencyCode: String, locale: Locale = .current) -> Money? {
        let separator = locale.decimalSeparator ?? "."
        let plain = text.replacingOccurrences(of: separator, with: ".")
        guard let amount = Decimal(string: plain, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return Money(amount: amount, currencyCode: currencyCode)
    }

    /// How an amount looks in an editable field: no symbol or grouping.
    static func text(for money: Money, locale: Locale = .current) -> String {
        money.amount.formatted(
            .number.grouping(.never)
                .precision(.fractionLength(CurrencyPrecision.fractionDigits(for: money.currencyCode)))
                .locale(locale)
        )
    }
}
