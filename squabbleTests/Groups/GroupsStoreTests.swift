import Foundation
import Testing
@testable import squabble

struct GroupsStoreTests {
    private func group(_ id: String, name: String, updatedAt: Date?) -> SquabbleGroup {
        SquabbleGroup(id: id, name: name, currencyCode: "EUR", createdBy: "pal", updatedAt: updatedAt, memberIds: ["pal"], members: [:])
    }

    @Test func sortsNewestFirstWithJustCreatedOnTop() {
        let groups = [
            group("old", name: "Old", updatedAt: Date(timeIntervalSince1970: 1)),
            group("new", name: "New", updatedAt: Date(timeIntervalSince1970: 2)),
            group("pending", name: "Pending", updatedAt: nil),
        ]
        #expect(GroupsStore.sorted(groups).map(\.id) == ["pending", "new", "old"])
    }

    @Test func breaksTiesByName() {
        let same = Date(timeIntervalSince1970: 5)
        let groups = [group("b", name: "Beta", updatedAt: same), group("a", name: "alpha", updatedAt: same)]
        #expect(GroupsStore.sorted(groups).map(\.id) == ["a", "b"])
    }
}
