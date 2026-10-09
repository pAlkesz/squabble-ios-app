import Foundation
import Testing
@testable import squabble

struct HungarianAccountNumberTests {
    @Test(arguments: ["11773016-11111018", "1177301611111018", "11773016 11111018 00000000"])
    func convertsToItsIBAN(input: String) throws {
        let number = try HungarianAccountNumber(validating: input)
        #expect(number.iban?.value == "HU42117730161111101800000000")
    }

    @Test func roundTripsThroughTheIBAN() throws {
        let iban = try IBAN(validating: "HU42 1177 3016 1111 1018 0000 0000")
        let number = try #require(HungarianAccountNumber(iban: iban))
        #expect(number.formatted == "11773016-11111018")
        #expect(number.iban == iban)
    }

    @Test func keepsAllThreeBlocksOfA24DigitNumber() throws {
        let iban = try IBAN(validating: "HU93116000060000000012345676")
        let number = try #require(HungarianAccountNumber(iban: iban))
        #expect(number.formatted == "11600006-00000000-12345676")
        #expect(try HungarianAccountNumber(validating: number.formatted).iban == iban)
    }

    @Test func rejectsTyposWithTheDomesticCheckDigits() {
        #expect(throws: HungarianAccountNumberError.checksumMismatch) {
            try HungarianAccountNumber(validating: "11773016-11111019")
        }
        #expect(throws: HungarianAccountNumberError.checksumMismatch) {
            try HungarianAccountNumber(validating: "11773017-11111018")
        }
    }

    @Test func rejectsTheWrongShape() {
        #expect(throws: HungarianAccountNumberError.wrongLength) {
            try HungarianAccountNumber(validating: "1177301611")
        }
        #expect(throws: HungarianAccountNumberError.invalidFormat) {
            try HungarianAccountNumber(validating: "1177301611111O18")
        }
    }

    @Test func otherCountriesHaveNoDomesticForm() throws {
        #expect(HungarianAccountNumber(iban: try IBAN(validating: "DE89370400440532013000")) == nil)
    }

    @Test func theSingleFieldAcceptsEitherForm() throws {
        let expected = try IBAN(validating: "HU42117730161111101800000000")
        #expect(try IBAN(validatingAccountNumber: "11773016-11111018") == expected)
        #expect(try IBAN(validatingAccountNumber: "hu42 1177 3016 1111 1018 0000 0000") == expected)
        #expect(try IBAN(validatingAccountNumber: "DE89 3704 0044 0532 0130 00").value == "DE89370400440532013000")
    }

    @Test func hungarianReadersSeeTheDomesticFormat() throws {
        let iban = try IBAN(validating: "HU42117730161111101800000000")
        #expect(iban.preferredFormat(for: .hungary) == "11773016-11111018")
        #expect(iban.preferredFormat(for: .germany) == "HU42 1177 3016 1111 1018 0000 0000")
    }
}
