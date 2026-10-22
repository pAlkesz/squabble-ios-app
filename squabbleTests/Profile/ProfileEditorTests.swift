import Foundation
import Testing
@testable import squabble

struct ProfileEditorTests {
    private let profiles = FakeProfileRepository()
    private let avatars = FakeAvatarStore()

    private var editor: ProfileEditor {
        ProfileEditor(profiles: profiles, avatars: avatars)
    }

    private func profile(avatar: Avatar = .persona(.bigSpender, .plum)) throws -> UserProfile {
        UserProfile(id: "uid-1", displayName: "Pal", handle: try Handle(validating: "pal"), avatar: avatar)
    }

    @Test func renameTrimsAndKeepsTheHandle() throws {
        let original = try profile()
        profiles.seed(original)
        try editor.rename(original, to: "  Pál Papp  ")
        #expect(profiles.profiles["uid-1"]?.displayName == "Pál Papp")
        #expect(profiles.profiles["uid-1"]?.handle == original.handle)
    }

    @Test(arguments: ["   ", String(repeating: "a", count: 51)])
    func renameRejectsInvalidNames(_ name: String) throws {
        let original = try profile()
        profiles.seed(original)
        #expect(throws: ProfileError.invalidDisplayName) {
            try editor.rename(original, to: name)
        }
        #expect(profiles.profiles["uid-1"] == original)
    }

    @Test func newPhotoReplacesTheAvatarAndSweepsOlderUploads() async throws {
        let original = try profile()
        profiles.seed(original)
        try await editor.setPhoto(Data([1]), on: original)
        let first = try #require(profiles.profiles["uid-1"])
        try await editor.setPhoto(Data([2]), on: first)

        let avatar = try #require(profiles.profiles["uid-1"]?.avatar)
        #expect(avatar.photoPath == "avatars/uid-1/2.jpg")
        #expect(avatars.deletedPaths.contains("avatars/uid-1/1.jpg"))
        #expect(!avatars.deletedPaths.contains("avatars/uid-1/2.jpg"))
    }

    @Test func removingThePhotoFallsBackToAPersonaAndDeletesIt() async throws {
        let original = try profile()
        profiles.seed(original)
        try await editor.setPhoto(Data([1]), on: original)
        let withPhoto = try #require(profiles.profiles["uid-1"])

        try await editor.removePhoto(from: withPhoto)

        guard case .persona = profiles.profiles["uid-1"]?.avatar else {
            Issue.record("Expected a persona avatar")
            return
        }
        #expect(avatars.deletedPaths.contains("avatars/uid-1/1.jpg"))
    }
}
