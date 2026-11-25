import Foundation
import Testing
@testable import squabble

struct MoneyTests {
    @Test(arguments: [("EUR", 2), ("HUF", 0), ("JPY", 0), ("KWD", 3), ("XYZ", 2)])
    func precision(code: String, digits: Int) {
        #expect(CurrencyPrecision.fractionDigits(for: code) == digits)
    }

    @Test func convertsExactlyBothWays() throws {
        let amount = try #require(Decimal(string: "-12.34", locale: Locale(identifier: "en_US")))
        let money = try #require(Money(amount: amount, currencyCode: "EUR"))
        #expect(money.minorUnits == -1234)
        #expect(money.amount == amount)
        #expect(Money(amount: 5000, currencyCode: "HUF")?.minorUnits == 5000)
    }

    @Test func refusesRatherThanRounds() throws {
        let fraction = try #require(Decimal(string: "1.005", locale: Locale(identifier: "en_US")))
        #expect(Money(amount: fraction, currencyCode: "EUR") == nil)
        #expect(Money(amount: fraction, currencyCode: "HUF") == nil)
        #expect(Money(amount: .nan, currencyCode: "EUR") == nil)
        #expect(Money(amount: Decimal(Int64.max), currencyCode: "EUR") == nil)
    }

    @Test(arguments: [Int64.max, Int64.min])
    func extremesSurvive(units: Int64) {
        let money = Money(minorUnits: units, currencyCode: "EUR")
        #expect(Money(amount: money.amount, currencyCode: "EUR") == money)
    }

    @Test func forintsShowNoDecimals() {
        let text = Money(minorUnits: 1500, currencyCode: "HUF").formatted(locale: Locale(identifier: "en_US"))
        #expect(text.contains("1,500"))
        #expect(!text.contains("."))
    }
}
