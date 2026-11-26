import Foundation
import Testing
@testable import squabble

@MainActor
struct SquabbleActivityTests {
    private func group(members: [String], activity: SquabbleActivity? = nil) -> SquabbleGroup {
        let entries = members.map { GroupMember(profile: GroupTestData.profile($0)) }
        return SquabbleGroup(
            id: "g1", name: "Trip", currencyCode: "EUR", createdBy: members[0],
            memberIds: members, members: Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) }),
            lastActivity: activity
        )
    }

    @Test func beforeAnythingHappensTheRowSaysWhatToDoFirst() {
        #expect(SquabbleRowSummary.text(for: group(members: ["pal"]), me: "pal") == "Invite people to the squabble")
        #expect(SquabbleRowSummary.text(for: group(members: ["pal", "anna"]), me: "pal") == "No messages yet. Say hello!")
    }

    @Test func theLatestThingSaysWhoDidIt() {
        let message = SquabbleActivity(kind: .message, by: "anna", id: "m1", text: "Pizza?\nOr sushi")
        #expect(SquabbleRowSummary.text(for: group(members: ["pal", "anna"], activity: message), me: "pal") == "Anna: Pizza? Or sushi")
        let mine = SquabbleActivity(kind: .billAdded, by: "pal", id: "b1", text: "Dinner")
        #expect(SquabbleRowSummary.text(for: group(members: ["pal", "anna"], activity: mine), me: "pal") == "You added “Dinner”")
        // Still true once the others have left.
        let deleted = SquabbleActivity(kind: .messageDeleted, by: "pal", id: "m1")
        #expect(SquabbleRowSummary.text(for: group(members: ["pal"], activity: deleted), me: "pal") == "You deleted a message")
    }

    @Test func roundTripsAndCapsTheText() {
        let activity = SquabbleActivity(kind: .billEdited, by: "pal", id: "b1", text: String(repeating: "x", count: 500))
        #expect(activity.text?.count == SquabbleActivity.maxTextLength)
        #expect(SquabbleActivity(firestoreData: activity.firestoreData) == activity)
    }

    @Test func anUnknownKindReadsAsNothing() throws {
        #expect(SquabbleActivity(firestoreData: ["kind": "settlement", "by": "pal", "id": "s1"]) == nil)
        let data: [String: Any] = [
            "name": "Trip", "currency": "EUR", "createdBy": "pal", "memberIds": ["pal"],
            "lastActivity": ["kind": "message", "by": "pal", "id": "m1", "text": "Hi"],
        ]
        #expect(try SquabbleGroup(id: "g1", firestoreData: data).lastActivity?.text == "Hi")
    }
}

struct SquabbleInvolvementTests {
    private func group(balances: [String: Int64]?, involved: Set<String>?) -> SquabbleGroup {
        SquabbleGroup(
            id: "g1", name: "Trip", currencyCode: "EUR", createdBy: "pal",
            memberIds: ["pal", "anna"], members: [:], balances: balances, involvedIDs: involved
        )
    }

    @Test func settledUpNeedsABillYouAreIn() {
        #expect(!group(balances: nil, involved: nil).isInvolved("pal"))
        #expect(group(balances: [:], involved: ["pal", "anna"]).isInvolved("pal"))
        #expect(!group(balances: [:], involved: ["anna"]).isInvolved("pal"))
        // Balances from before the server kept track: everyone counts.
        #expect(group(balances: [:], involved: nil).isInvolved("pal"))
    }

    @Test func readsTheInvolvedList() throws {
        let data: [String: Any] = [
            "name": "Trip", "currency": "EUR", "createdBy": "pal", "memberIds": ["pal"],
            "balances": [String: Int64](), "involvedIds": ["pal"],
        ]
        #expect(try SquabbleGroup(id: "g1", firestoreData: data).involvedIDs == ["pal"])
    }
}
