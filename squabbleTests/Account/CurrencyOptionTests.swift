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

    @Test func doesNotMatchUnrelatedQueries() throws {
        let forint = try #require(options.first { $0.code == "HUF" })
        #expect(!forint.matches("yen"))
    }
}
