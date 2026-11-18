import Foundation
import Testing
@testable import squabble

struct OwnEntrySyncTests {
    private let me = GroupTestData.profile("pal")
    private let joined = Date(timeIntervalSince1970: 1_000)

    private func group(
        id: String = "g1",
        entry: GroupMember? = nil,
        isMember: Bool = true,
        archived: Bool = false
    ) -> SquabbleGroup {
        let mine = entry ?? GroupMember(profile: me, paymentMethods: [])
        let other = GroupMember(profile: GroupTestData.profile("anna"))
        return SquabbleGroup(
            id: id,
            name: "Trip",
            currencyCode: "EUR",
            createdBy: "anna",
            archivedAt: archived ? joined : nil,
            memberIds: isMember ? ["anna", "pal"] : ["anna"],
            members: ["anna": other, "pal": mine]
        )
    }

    @Test func upToDateEntriesNeedNothing() {
        let updates = OwnEntrySync.updates(for: [group()], profile: me, paymentMethods: [])
        #expect(updates.isEmpty)
    }

    @Test func copiesNewProfileAndPaymentDetailsKeepingWhenTheyJoined() throws {
        var stale = GroupMember(profile: me)
        stale.displayName = "Old name"
        stale.joinedAt = joined
        let payment = [GroupTestData.revolut("pal")]

        let updates = OwnEntrySync.updates(for: [group(entry: stale)], profile: me, paymentMethods: payment)

        let update = try #require(updates.first)
        #expect(updates.count == 1)
        #expect(update.groupID == "g1")
        #expect(update.entry.displayName == me.displayName)
        #expect(update.entry.paymentMethods == payment)
        #expect(update.entry.joinedAt == joined)
    }

    @Test func skipsArchivedSquabblesAndOnesTheUserLeft() {
        var stale = GroupMember(profile: me)
        stale.displayName = "Old name"
        let groups = [
            group(id: "archived", entry: stale, archived: true),
            group(id: "left", entry: stale, isMember: false),
        ]
        #expect(OwnEntrySync.updates(for: groups, profile: me, paymentMethods: []).isEmpty)
    }
}
