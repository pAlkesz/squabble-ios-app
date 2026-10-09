import Testing
@testable import squabble

struct BankAccountNumberFormatterTests {
    @Test(arguments: [
        ("1177301611111018", "11773016-11111018"),
        ("117730161111101800000000", "11773016-11111018-00000000"),
        ("11773016", "11773016"),
        ("117730161", "11773016-1"),
        ("11773016-", "11773016"),
        ("1177 3016-1111", "11773016-1111"),
        ("1177301611111018000000001234", "11773016-11111018-00000000"),
    ])
    func groupsDomesticNumbersInEights(input: String, expected: String) {
        #expect(BankAccountNumberFormatter.format(input) == expected)
    }

    @Test(arguments: [
        ("hu42117730161111101800000000", "HU42 1177 3016 1111 1018 0000 0000"),
        ("HU42", "HU42"),
        ("HU421", "HU42 1"),
        ("HU42 ", "HU42"),
        ("de89-3704-0044", "DE89 3704 0044"),
    ])
    func groupsIBANsInFours(input: String, expected: String) {
        #expect(BankAccountNumberFormatter.format(input) == expected)
    }

    @Test func capsAnIBANAtItsLongestLength() {
        let long = "GB" + String(repeating: "1", count: 40)
        #expect(BankAccountNumberFormatter.format(long).filter { $0 != " " }.count == IBAN.lengthRange.upperBound)
    }

    @Test func formattedNumbersStillValidate() throws {
        let formatted = BankAccountNumberFormatter.format("1177301611111018")
        #expect(try IBAN(validatingAccountNumber: formatted).value == "HU42117730161111101800000000")
    }
}
