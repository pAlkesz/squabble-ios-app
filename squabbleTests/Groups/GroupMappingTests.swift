import Foundation
import Testing
@testable import squabble

struct GroupMappingTests {
    @Test(arguments: [
        SquabbleImage.emoji("👨‍👩‍👧", .coral),
        .photo(path: "groupImages/pal/a.jpg", url: URL(string: "https://example.com/a.jpg")!),
    ])
    func groupRoundTripsWithoutTimestamps(image: SquabbleImage) throws {
        let members = [GroupMember(profile: GroupTestData.profile("pal"), paymentMethods: [GroupTestData.revolut("pal")]),
                       GroupMember(profile: GroupTestData.profile("anna"))]
        let group = SquabbleGroup(
            id: "g1", name: "Flat 4B", currencyCode: "EUR", image: image, createdBy: "pal",
            memberIds: members.map(\.id), members: Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        )
        #expect(try SquabbleGroup(id: "g1", firestoreData: group.firestoreData) == group)
    }

    @Test func missingOrUnreadableImageFallsBackToTheDefault() throws {
        let base: [String: Any] = ["name": "Trip", "currency": "EUR", "createdBy": "pal", "memberIds": ["pal"]]
        var unreadable = base
        unreadable["image"] = ["kind": "hologram"]
        #expect(try SquabbleGroup(id: "g1", firestoreData: base).image == .default(for: "g1"))
        #expect(try SquabbleGroup(id: "g1", firestoreData: unreadable).image == .default(for: "g1"))
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
