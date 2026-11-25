import Foundation

/// Mapping from `rates/latest`, written only by the `updateRates` function.
nonisolated extension ExchangeRates {
    init?(firestoreData data: [String: Any]) {
        guard data["base"] as? String == "EUR",
              let date = data["date"] as? String,
              let rates = data["rates"] as? [String: String]
        else { return nil }
        self.init(date: date, unitsPerEuro: rates.compactMapValues {
            Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX"))
        })
    }
}
