import Testing
@testable import squabble

struct AvatarColorTests {
    @Test func defaultIsStableForTheSameUser() {
        #expect(AvatarColor.default(for: "uid-1") == AvatarColor.default(for: "uid-1"))
    }

    @Test func defaultsSpreadAcrossPresets() {
        let picks = Set((0..<200).map { AvatarColor.default(for: "user-\($0)") })
        #expect(picks == Set(AvatarColor.allCases))
    }
}
