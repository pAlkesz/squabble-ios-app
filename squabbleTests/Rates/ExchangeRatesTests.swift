import Foundation
import Testing
@testable import squabble

struct ExchangeRatesTests {
    @Test func readsTheDocumentExactly() throws {
        let rates = try #require(ExchangeRates(firestoreData: [
            "base": "EUR", "date": "2026-11-25", "rates": ["HUF": "373.44", "BAD": "x", "ZERO": "0"],
        ]))
        #expect(rates.date == "2026-11-25")
        #expect(rates.unitsPerEuro(of: "HUF") == Decimal(string: "373.44"))
        #expect(rates.unitsPerEuro(of: "EUR") == 1)
        #expect(rates.unitsPerEuro(of: "BAD") == nil)
        #expect(rates.unitsPerEuro(of: "ZERO") == nil)
    }

    @Test func refusesAnotherBase() {
        #expect(ExchangeRates(firestoreData: ["base": "USD", "date": "2026-11-25", "rates": ["HUF": "1"]]) == nil)
        #expect(ExchangeRates(firestoreData: [:]) == nil)
    }

    @Test func convertsBetweenAnyTwo() {
        let rates = ExchangeRates(date: "2026-11-25", unitsPerEuro: ["HUF": 400, "USD": 1.25])
        #expect(rates.amount(of: Money(minorUnits: 500, currencyCode: "USD"), in: "HUF") == 1600)
        #expect(rates.amount(of: Money(minorUnits: -1600, currencyCode: "HUF"), in: "USD") == -5)
        #expect(rates.amount(of: Money(minorUnits: 100, currencyCode: "RSD"), in: "RSD") == 1)
        #expect(rates.amount(of: Money(minorUnits: 100, currencyCode: "RSD"), in: "EUR") == nil)
    }

    @Test func roundsHalfAwayFromZero() {
        #expect(Money(rounding: Decimal(string: "0.5") ?? 0, currencyCode: "HUF")?.minorUnits == 1)
        #expect(Money(rounding: Decimal(string: "-0.5") ?? 0, currencyCode: "HUF")?.minorUnits == -1)
        #expect(Money(rounding: Decimal(string: "1.005") ?? 0, currencyCode: "EUR")?.minorUnits == 101)
    }
}
