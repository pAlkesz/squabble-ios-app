import Testing
@testable import squabble

struct HandleTests {
    @Test func normalizesCaseWhitespaceAndLeadingAt() throws {
        #expect(try Handle(validating: "  @Pal_Papp ").rawValue == "pal_papp")
    }

    @Test(arguments: [
        ("", HandleError.missing),
        ("  @ ", .missing),
        ("ab", .tooShort),
        (String(repeating: "a", count: 33), .tooLong),
        ("pál", .invalidCharacters),
        ("pal.papp", .invalidCharacters),
        ("pal papp", .invalidCharacters),
    ])
    func rejectsInvalidHandles(input: String, expected: HandleError) {
        #expect(throws: expected) { try Handle(validating: input) }
    }

    @Test func describesItselfWithAt() throws {
        #expect(try Handle(validating: "pal").description == "@pal")
    }

    @Test(arguments: [
        ("Pál Papp", "pal_papp"),
        ("  Anna-Mária  Kovács ", "anna_maria_kovacs"),
        ("Łukasz", "ukasz"),
        ("", ""),
        ("A very long name that goes on and on and on", "a_very_long_name_that_goes_on_an"),
    ])
    func suggestsFromDisplayName(name: String, expected: String) {
        #expect(Handle.suggestion(from: name) == expected)
    }
}
