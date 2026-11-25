import Foundation
import Testing
@testable import squabble

struct HomeTotalTests {
    private let rates = ExchangeRates(date: "2026-11-25", unitsPerEuro: ["HUF": 400, "USD": 1.25])

    private func group(_ id: String, _ currency: String, _ balance: Int64) -> SquabbleGroup {
        var group = SquabbleGroup(id: id, name: id, currencyCode: currency, createdBy: "pal", memberIds: ["pal"], members: [:])
        group.balances = ["pal": balance]
        return group
    }

    private func total(_ groups: [SquabbleGroup], home: String = "HUF", rates: ExchangeRates?) -> HomeTotal {
        HomeTotal(groups: groups, uid: "pal", homeCurrencyCode: home, rates: rates)
    }

    @Test func withoutRatesAddsUpPerCurrency() {
        let total = total(
            [group("a", "HUF", 500), group("b", "HUF", -200), group("c", "USD", -700), group("d", "EUR", 100), group("e", "EUR", -100)],
            rates: nil
        )
        #expect(total.headline == Money(minorUnits: 300, currencyCode: "HUF"))
        #expect(total.others == [Money(minorUnits: -700, currencyCode: "USD")])
    }

    @Test func withoutRatesTheOnlyBalanceIsTheHeadlineWhateverItsCurrency() {
        let only = total([group("a", "EUR", 100), group("b", "HUF", 0)], rates: nil)
        #expect(only.headline == Money(minorUnits: 100, currencyCode: "EUR"))
        #expect(only.others.isEmpty)
        #expect(total([group("a", "EUR", 0)], rates: nil).headline == Money(minorUnits: 0, currencyCode: "HUF"))
    }

    @Test func convertsEverythingIntoTheHomeCurrency() {
        // 1,000 HUF − €10.00 (4,000 HUF) + $2.50 (€2.00, 800 HUF)
        let total = total([group("a", "HUF", 1000), group("b", "EUR", -1000), group("c", "USD", 250)], rates: rates)
        #expect(total.headline == Money(minorUnits: -2200, currencyCode: "HUF"))
        #expect(total.others.isEmpty)
    }

    @Test func aCurrencyWithoutARateIsShownSeparately() {
        let total = total([group("a", "EUR", 100), group("b", "RSD", -500)], rates: rates)
        #expect(total.headline == Money(minorUnits: 400, currencyCode: "HUF"))
        #expect(total.others == [Money(minorUnits: -500, currencyCode: "RSD")])
    }

    @Test func aHomeCurrencyWithoutARateConvertsNothing() {
        let total = total([group("a", "RSD", 100), group("b", "EUR", 200)], home: "RSD", rates: rates)
        #expect(total.headline == Money(minorUnits: 100, currencyCode: "RSD"))
        #expect(total.others == [Money(minorUnits: 200, currencyCode: "EUR")])
    }

    @Test func roundsOnceAtTheEnd() {
        // 0.4 of a forint each: rounded one by one they'd vanish.
        let rates = ExchangeRates(date: "2026-11-25", unitsPerEuro: ["HUF": 40, "USD": 1])
        let total = total([group("a", "EUR", 1), group("b", "USD", 1)], rates: rates)
        #expect(total.headline == Money(minorUnits: 1, currencyCode: "HUF"))
    }
}
