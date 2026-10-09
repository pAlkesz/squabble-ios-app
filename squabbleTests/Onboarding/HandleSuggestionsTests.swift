import Testing
@testable import squabble

struct HandleSuggestionsTests {
    @Test func decoratesTheTakenHandleInAFixedOrder() throws {
        let candidates = HandleSuggestions.candidates(for: try Handle(validating: "pal_papp"))
        #expect(candidates.map(\.rawValue) == ["pal_papp2", "pal_papp_pays", "the_pal_papp", "pal_papp_owed", "pal_papp3"])
    }

    @Test func longHandlesAreTrimmedToFitWithoutDanglingUnderscores() throws {
        let taken = try Handle(validating: "abcdefghijklmnopqrstuvwxyz_abcde")
        let candidates = HandleSuggestions.candidates(for: taken)
        #expect(candidates.count == 5)
        #expect(candidates.allSatisfy { Handle.lengthRange.contains($0.rawValue.count) })
        #expect(candidates.contains { $0.rawValue == "abcdefghijklmnopqrstuvwxyz_pays" })
        #expect(!candidates.contains(taken))
    }

    @Test func nameBasedCandidatesStartWithThePlainHandle() {
        let candidates = HandleSuggestions.candidates(fromName: "Pál Papp")
        #expect(candidates.map(\.rawValue) == ["pal_papp", "pal_papp2", "pal_papp_pays", "the_pal_papp", "pal_papp_owed", "pal_papp3"])
    }

    @Test func noNameMeansNoCandidates() {
        #expect(HandleSuggestions.candidates(fromName: "  ").isEmpty)
        #expect(HandleSuggestions.candidates(fromName: "Łó").isEmpty)
    }
}
