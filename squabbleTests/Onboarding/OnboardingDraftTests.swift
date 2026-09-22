import Foundation
import Testing
@testable import squabble

struct OnboardingDraftTests {
    private let user = AppUser(id: "uid-1", displayName: "Pál Papp")

    @Test func prefillsFromTheAppleName() {
        let draft = OnboardingDraft(user: user)
        #expect(draft.displayName == "Pál Papp")
        #expect(draft.handle == "pal_papp")
        #expect(draft.preset == .default(for: "uid-1"))
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

    @Test func buildsAProfileWithThePresetByDefault() throws {
        var draft = OnboardingDraft(user: user)
        draft.preset = .plum
        let profile = try #require(draft.profile(for: "uid-1"))
        #expect(profile.displayName == "Pál Papp")
        #expect(profile.handle.rawValue == "pal_papp")
        #expect(profile.avatar == .preset(.plum))
    }

    @Test func aPickedPhotoMustBeUploadedFirst() {
        var draft = OnboardingDraft(user: user)
        draft.setPhoto(Data([0xFF]))
        #expect(draft.profile(for: "uid-1") == nil)

        let uploaded = Avatar.photo(path: "avatars/uid-1/a.jpg", url: URL(string: "https://example.com/a.jpg")!)
        draft.uploadedPhoto = uploaded
        #expect(draft.profile(for: "uid-1")?.avatar == uploaded)

        draft.setPhoto(Data([0xFE]))
        #expect(draft.uploadedPhoto == nil)
    }

    @Test func trimsTheNameAndRejectsBlankOrOverlongOnes() {
        var draft = OnboardingDraft(user: user)
        draft.setDisplayName("  Pál  ")
        #expect(draft.validDisplayName == "Pál")
        draft.setDisplayName("   ")
        #expect(draft.validDisplayName == nil)
        draft.setDisplayName(String(repeating: "a", count: 41))
        #expect(draft.validDisplayName == nil)
    }

    @Test func capsPaymentMethods() throws {
        var draft = OnboardingDraft(user: user)
        let link = try PaymentLink(provider: .revolut, input: "pal")
        draft.paymentMethods = (0..<PaymentMethod.maxCount).map { _ in PaymentMethod(kind: .link(link)) }
        #expect(!draft.canAddPaymentMethod)
    }
}
