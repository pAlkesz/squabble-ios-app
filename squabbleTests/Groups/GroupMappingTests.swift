import Foundation
import Testing
@testable import squabble

struct GroupMappingTests {
    @Test func groupRoundTripsWithoutTimestamps() throws {
        var draft = NewSquabbleDraft(creator: GroupTestData.profile("pal"), currencyCode: "EUR")
        draft.setName("Flat 4B")
        draft.add(GroupTestData.profile("anna"))
        let group = try #require(draft.makeGroup(id: "g1", creatorPaymentMethods: [GroupTestData.revolut("pal")]))

        #expect(try SquabbleGroup(id: "g1", firestoreData: group.firestoreData) == group)
    }

    @Test func readsTimestampsAndDeletedMembers() throws {
        let joined = Date(timeIntervalSince1970: 1_000)
        let data: [String: Any] = [
            "name": "Trip",
            "currency": "HUF",
            "createdBy": "anna",
            "updatedAt": joined,
            "archivedAt": joined,
            "memberIds": ["anna"],
            "members": [
                "anna": ["displayName": "Anna", "handle": "anna", "avatar": ["kind": "preset", "preset": "plum"], "joinedAt": joined],
                "gone": ["deleted": true],
            ],
        ]

        let group = try SquabbleGroup(id: "g1", firestoreData: data)

        #expect(group.isArchived)
        #expect(group.updatedAt == joined)
        #expect(group.members["anna"]?.joinedAt == joined)
        #expect(group.members["gone"]?.isDeleted == true)
        #expect(group.members["gone"]?.avatar == .preset(.default(for: "gone")))
        #expect(group.currentMembers.map(\.id) == ["anna"])
    }

    @Test func memberIdsWithoutAnEntryAreLeftOutOfCurrentMembers() throws {
        let data: [String: Any] = [
            "name": "Trip", "currency": "EUR", "createdBy": "anna",
            "memberIds": ["anna", "ghost"],
            "members": ["anna": ["displayName": "Anna"]],
        ]
        #expect(try SquabbleGroup(id: "g1", firestoreData: data).currentMembers.map(\.id) == ["anna"])
    }

    @Test func missingFieldsAreMalformed() {
        #expect(throws: FirestoreMappingError.malformed("groups/g1")) {
            try SquabbleGroup(id: "g1", firestoreData: ["name": "Trip"])
        }
    }

    @Test func memberEntryLeavesServerOwnedFieldsOut() {
        var member = GroupMember(profile: GroupTestData.profile("pal"))
        member.joinedAt = Date()
        member.isDeleted = true
        #expect(Set(member.firestoreData.keys) == ["displayName", "handle", "avatar", "payment"])
    }
}
