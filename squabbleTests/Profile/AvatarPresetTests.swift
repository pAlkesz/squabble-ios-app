import Testing
@testable import squabble

struct AvatarPresetTests {
    @Test func defaultIsStableForTheSameUser() {
        #expect(AvatarPreset.default(for: "uid-1") == AvatarPreset.default(for: "uid-1"))
    }

    @Test func defaultsSpreadAcrossPresets() {
        let picks = Set((0..<200).map { AvatarPreset.default(for: "user-\($0)") })
        #expect(picks == Set(AvatarPreset.allCases))
    }
}
