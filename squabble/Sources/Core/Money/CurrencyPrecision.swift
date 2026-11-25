/// How many decimals a currency's amounts have. Its own table rather than the system's, so
/// the app and the server agree on what a stored minor unit means on every OS version.
nonisolated enum CurrencyPrecision {
    static func fractionDigits(for currencyCode: String) -> Int {
        overrides[currencyCode] ?? iso4217[currencyCode] ?? 2
    }

    /// Currencies whose subunit nobody uses (docs/specs/bills.md). Changing an entry changes
    /// the meaning of amounts already stored.
    private static let overrides = ["HUF": 0]

    /// ISO 4217 exponents other than 2.
    private static let iso4217 = [
        "BIF": 0, "CLP": 0, "DJF": 0, "GNF": 0, "ISK": 0, "JPY": 0, "KMF": 0, "KRW": 0, "PYG": 0,
        "RWF": 0, "UGX": 0, "UYI": 0, "VND": 0, "VUV": 0, "XAF": 0, "XOF": 0, "XPF": 0,
        "BHD": 3, "IQD": 3, "JOD": 3, "KWD": 3, "LYD": 3, "OMR": 3, "TND": 3,
        "CLF": 4, "UYW": 4,
    ]
}
