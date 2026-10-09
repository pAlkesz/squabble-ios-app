import Foundation
import Testing
@testable import squabble

struct OnboardingDraftTests {
    private let user = AppUser(id: "uid-1", displayName: "Pál Papp")

    @Test func prefillsFromTheAppleName() {
        let draft = OnboardingDraft(user: user)
        #expect(draft.displayName == "Pál Papp")
        #expect(draft.handle == "pal_papp")
        if case .persona = draft.avatarChoice {} else { Issue.record("Expected a persona by default") }
    }

    @Test func dealsEveryPersonaAColourOfItsOwn() {
        let options = OnboardingDraft.dealOptions()
        #expect(options.count == AvatarPersona.allCases.count)
        let colors = options.compactMap { option -> AvatarColor? in
            if case .persona(_, let color) = option { color } else { nil }
        }
        #expect(colors.count <= AvatarColor.allCases.count, "More tiles than colours: add colours or relax this test")
        #expect(Set(colors).count == colors.count)
    }

    @Test func startsEmptyWithoutAnAppleName() {
        let draft = OnboardingDraft(user: AppUser(id: "uid-1", displayName: nil))
        #expect(draft.displayName.isEmpty)
        #expect(draft.profile(for: "uid-1") == nil)
    }

    @Test func handleFollowsTheNameUntilEdited() {
        var draft = OnboardingDraft(user: user)
        draft.setDisplayName("Anna")
        #expect(draft.handle == "anna")

        draft.setHandle("squabmaster")
        draft.setDisplayName("Anna Kovács")
        #expect(draft.handle == "squabmaster")
    }

    @Test func buildsAProfileWithTheChosenPersona() throws {
        var draft = OnboardingDraft(user: user)
        draft.choose(.persona(.artExpert, .lagoon))
        let profile = try #require(draft.profile(for: "uid-1"))
        #expect(profile.displayName == "Pál Papp")
        #expect(profile.handle.rawValue == "pal_papp")
        #expect(profile.avatar == .persona(.artExpert, .lagoon))
    }

    @Test func aChosenPersonaIsSavedWithItsColourAndNoUpload() throws {
        var draft = OnboardingDraft(user: user)
        draft.choose(.persona(.bigSpender, .coral))
        #expect(draft.photoToUpload == nil)
        #expect(try #require(draft.profile(for: "uid-1")).avatar == .persona(.bigSpender, .coral))
    }

    @Test func aPickedPhotoIsChosenAndMustBeUploadedFirst() {
        var draft = OnboardingDraft(user: user)
        draft.setPhoto(Data([0xFF]))
        #expect(draft.avatarChoice == .photo)
        #expect(draft.photoToUpload == Data([0xFF]))
        #expect(draft.profile(for: "uid-1") == nil)

        let uploaded = Avatar.photo(path: "avatars/uid-1/a.jpg", url: URL(string: "https://example.com/a.jpg")!)
        draft.uploadedPhoto = uploaded
        #expect(draft.photoToUpload == nil)
        #expect(draft.profile(for: "uid-1")?.avatar == uploaded)

        draft.setPhoto(Data([0xFE]))
        #expect(draft.uploadedPhoto == nil)
    }

    @Test func switchingAwayFromThePhotoKeepsItButSkipsTheUpload() {
        var draft = OnboardingDraft(user: user)
        draft.setPhoto(Data([0xFF]))
        draft.choose(.persona(.bigSpender, .coral))
        #expect(draft.photoJPEG == Data([0xFF]))
        #expect(draft.photoToUpload == nil)

        draft.choose(.photo)
        #expect(draft.photoToUpload == Data([0xFF]))
    }

    @Test func thePhotoCantBeChosenBeforeThereIsOne() {
        var draft = OnboardingDraft(user: user)
        let before = draft.avatarChoice
        draft.choose(.photo)
        #expect(draft.avatarChoice == before)
    }

    @Test func trimsTheNameAndRejectsBlankOrOverlongOnes() {
        var draft = OnboardingDraft(user: user)
        draft.setDisplayName("  Pál  ")
        #expect(draft.validDisplayName == "Pál")
        draft.setDisplayName("   ")
        #expect(draft.validDisplayName == nil)
        #expect(UserProfile.validDisplayName(String(repeating: "a", count: 51)) == nil)
    }

    @Test func capsPaymentMethods() throws {
        var draft = OnboardingDraft(user: user)
        let link = try PaymentLink(provider: .revolut, input: "pal")
        draft.paymentMethods = (0..<PaymentMethod.maxCount).map { _ in PaymentMethod(kind: .link(link)) }
        #expect(!draft.canAddPaymentMethod)
    }

    @Test func neverHoldsMoreThanTheLimits() {
        var draft = OnboardingDraft(user: user)
        draft.setDisplayName(String(repeating: "a", count: 60))
        #expect(draft.displayName.count == UserProfile.maxDisplayNameLength)
        #expect(draft.handle.count <= Handle.lengthRange.upperBound)
        draft.setHandle(String(repeating: "b", count: 40))
        #expect(draft.handle.count == Handle.lengthRange.upperBound)
    }
}
