import Foundation
import Testing
@testable import squabble

struct NewSquabbleDraftTests {
    private let creator = GroupTestData.profile("pal")

    private func draft() -> NewSquabbleDraft {
        NewSquabbleDraft(creator: creator, currencyCode: "HUF")
    }

    @Test func addsPeopleOnceAndNeverTheCreator() {
        var draft = draft()
        let anna = GroupTestData.profile("anna")
        #expect(draft.add(anna) == .added)
        #expect(draft.add(anna) == .alreadyAdded)
        #expect(draft.add(creator) == .isCreator)
        #expect(draft.members == [anna])
        #expect(draft.memberCount == 2)
    }

    @Test func stopsAtTheMemberLimitCountingTheCreator() {
        var draft = draft()
        for index in 1..<SquabbleGroup.maxMembers {
            #expect(draft.add(GroupTestData.profile("member\(index)")) == .added)
        }
        #expect(draft.memberCount == SquabbleGroup.maxMembers)
        #expect(draft.add(GroupTestData.profile("onetoomany")) == .full)
    }

    @Test func removesAMember() {
        var draft = draft()
        draft.add(GroupTestData.profile("anna"))
        draft.remove("anna")
        #expect(draft.members.isEmpty)
    }

    @Test(arguments: ["", "   ", String(repeating: "x", count: 51)])
    func rejectsInvalidNames(_ name: String) {
        var draft = draft()
        draft.name = name
        #expect(!draft.canCreate)
        #expect(draft.makeGroup(id: "g", creatorPaymentMethods: []) == nil)
    }

    @Test func setNameDropsAnythingPastTheLimit() {
        var draft = draft()
        draft.setName(String(repeating: "x", count: 80))
        #expect(draft.name.count == SquabbleGroup.maxNameLength)
    }

    @Test func makesAGroupWithTheCreatorFirstAndOnlyTheirPaymentDetails() throws {
        var draft = draft()
        draft.setName("  Lake trip  ")
        draft.add(GroupTestData.profile("anna"))
        draft.add(GroupTestData.profile("bence"))
        let payment = [GroupTestData.revolut("pal")]

        let group = try #require(draft.makeGroup(id: "g1", creatorPaymentMethods: payment))

        #expect(group.name == "Lake trip")
        #expect(group.currencyCode == "HUF")
        #expect(group.createdBy == "pal")
        #expect(group.memberIds == ["pal", "anna", "bence"])
        #expect(group.members["pal"]?.paymentMethods == payment)
        #expect(group.members["anna"]?.paymentMethods == [])
        #expect(group.currentMembers.map(\.id) == ["pal", "anna", "bence"])
    }
}
