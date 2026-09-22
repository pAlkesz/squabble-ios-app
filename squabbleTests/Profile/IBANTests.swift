import Testing
@testable import squabble

struct IBANTests {
    @Test(arguments: [
        "HU42 1177 3016 1111 1018 0000 0000",
        "DE89 3704 0044 0532 0130 00",
        "gb82 west 1234 5698 7654 32",
        "NO9386011117947",
    ])
    func acceptsValidIBANs(input: String) throws {
        let iban = try IBAN(validating: input)
        #expect(iban.value == input.uppercased().filter { $0 != " " })
    }

    @Test func formatsInGroupsOfFour() throws {
        #expect(try IBAN(validating: "DE89370400440532013000").formatted == "DE89 3704 0044 0532 0130 00")
    }

    @Test func catchesTypos() {
        #expect(throws: IBANError.checksumMismatch) { try IBAN(validating: "DE89370400440532013001") }
        #expect(throws: IBANError.checksumMismatch) { try IBAN(validating: "DE98370400440532013000") }
    }

    @Test func rejectsMalformedInput() {
        #expect(throws: IBANError.wrongLength) { try IBAN(validating: "DE89 3704") }
        #expect(throws: IBANError.invalidFormat) { try IBAN(validating: "1289370400440532013000") }
        #expect(throws: IBANError.invalidFormat) { try IBAN(validating: "DE89370400440532013€00") }
    }
}
