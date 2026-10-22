import Foundation
import Testing
@testable import squabble

struct CurrencyOptionTests {
    private let options = CurrencyOption.all(in: Locale(identifier: "en_US"))

    @Test func listsCommonCurrenciesSortedByName() {
        #expect(options.contains { $0.code == "HUF" && $0.name == "Hungarian Forint" })
        #expect(options.map(\.name) == options.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test(arguments: ["huf", "forint", "Hungarian", ""])
    func matchesCodeOrName(_ query: String) throws {
        let forint = try #require(options.first { $0.code == "HUF" })
        #expect(forint.matches(query))
    }

    @Test(arguments: [("HUF", "HU", "Hungary"), ("USD", "US", "United States"), ("GBP", "GB", "United Kingdom"), ("CHF", "CH", "Switzerland")])
    func nationalCurrenciesGetTheirCountry(code: String, region: String, country: String) {
        let option = CurrencyOption(code: code, locale: Locale(identifier: "en_US"))
        #expect(option.flagRegion == region)
        #expect(option.countryName == country)
    }

    @Test func euroGetsTheEUFlag() {
        let euro = CurrencyOption(code: "EUR", locale: Locale(identifier: "en_US"))
        #expect(euro.flag == "🇪🇺")
        #expect(euro.countryName == "European Union")
    }

    @Test func sharedCurrenciesGetNoFlag() {
        let franc = CurrencyOption(code: "XOF", locale: Locale(identifier: "en_US"))
        #expect(franc.flag == nil)
        #expect(franc.countryName == nil)
    }

    @Test func searchMatchesTheCountry() throws {
        let forint = try #require(options.first { $0.code == "HUF" })
        #expect(forint.matches("hungary"))
    }

    @Test func doesNotMatchUnrelatedQueries() throws {
        let forint = try #require(options.first { $0.code == "HUF" })
        #expect(!forint.matches("yen"))
    }
}
