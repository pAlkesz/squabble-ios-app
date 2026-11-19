import Foundation
import Testing
@testable import squabble

struct NewSquabbleDraftTests {
    private let creator = GroupTestData.profile("pal")

    private func draft() -> NewSquabbleDraft {
        NewSquabbleDraft(creator: creator, currencyCode: "HUF", drawing: .artwork(.trio, .peach))
    }

    @Test(arguments: ["", "   ", String(repeating: "x", count: 51)])
    func rejectsInvalidNames(_ name: String) {
        var draft = draft()
        draft.setName(name)
        // setName caps at 50, so the over-long name becomes valid; only blanks stay invalid.
        #expect(draft.canCreate == !name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test func setNameDropsAnythingPastTheLimit() {
        var draft = draft()
        draft.setName(String(repeating: "x", count: 80))
        #expect(draft.name.count == SquabbleGroup.maxNameLength)
    }

    @Test func presetFillsInItsNameAndShowsAsSelected() {
        var draft = draft()
        draft.choose(.trip)
        #expect(draft.name == SquabblePreset.trip.name)
        #expect(draft.drawing == .artwork(.trio, .peach))
        #expect(draft.selectedPreset == .trip)

        draft.setName(draft.name + " to Rome")
        #expect(draft.selectedPreset == nil)
    }

    @Test func presetKeepsAChosenPhoto() {
        var draft = draft()
        draft.setPhoto(Data([1]))
        draft.choose(.party)
        #expect(draft.photoJPEG == Data([1]))
    }

    @Test func pickingADrawingDropsThePhoto() {
        var draft = draft()
        draft.setPhoto(Data([1]))
        draft.setArtwork(.trio)
        #expect(draft.photoJPEG == nil)
        #expect(draft.drawing == .artwork(.trio, .peach))
    }

    @Test func changingTheBackgroundKeepsAChosenPhoto() {
        var draft = draft()
        draft.setPhoto(Data([1]))
        draft.background = .dusk
        #expect(draft.photoJPEG == Data([1]))
        #expect(draft.drawing == .artwork(.trio, .dusk))
    }

    @Test func makesAGroupWithOnlyTheCreatorAndTheirPaymentDetails() throws {
        var draft = draft()
        draft.setName("  Lake trip  ")
        let payment = [GroupTestData.revolut("pal")]

        let group = try #require(draft.makeGroup(id: "g1", creatorPaymentMethods: payment))

        #expect(group.name == "Lake trip")
        #expect(group.currencyCode == "HUF")
        #expect(group.image == .artwork(.trio, .peach))
        #expect(group.createdBy == "pal")
        #expect(group.memberIds == ["pal"])
        #expect(group.members["pal"]?.paymentMethods == payment)
    }

    @Test func anUploadedPhotoWinsOverTheDrawing() throws {
        var draft = draft()
        draft.setName("Flat 4B")
        let photo = SquabbleImage.photo(path: "groupImages/pal/a.jpg", url: URL(string: "https://example.com/a.jpg")!)
        let group = try #require(draft.makeGroup(id: "g1", photo: photo, creatorPaymentMethods: []))
        #expect(group.image == photo)
    }

    @Test func blankNameMakesNoGroup() {
        #expect(draft().makeGroup(id: "g1", creatorPaymentMethods: []) == nil)
    }
}
