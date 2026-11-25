import Testing
@testable import squabble

struct BillSplitTests {
    private let trio = ["anna", "bela", "cili"]

    private func item(_ amount: Int64, _ people: Set<String>) -> BillItem {
        BillItem(id: "item", name: "Nachos", amountMinor: amount, sharedBy: people)
    }

    @Test func equalSplitGivesLeftoversInBillOrder() throws {
        #expect(try BillSplit.equally(1000, among: trio) == ["anna": 334, "bela": 333, "cili": 333])
        #expect(try BillSplit.equally(1001, among: ["cili", "bela", "anna"]) == ["cili": 334, "bela": 334, "anna": 333])
        #expect(try BillSplit.equally(1, among: trio) == ["anna": 1, "bela": 0, "cili": 0])
        #expect(try BillSplit.equally(0, among: trio) == ["anna": 0, "bela": 0, "cili": 0])
    }

    @Test func largestRemainderGetsTheLeftover() throws {
        // 100 by 1:1:4 is 16⅔, 16⅔, 66⅔: a tie, so order decides.
        #expect(try BillSplit.proportionally(100, weights: ["anna": 1, "bela": 1, "cili": 4], among: trio) == ["anna": 17, "bela": 17, "cili": 66])
        // 10 by 1:2:4 is 1.43, 2.86, 5.71.
        #expect(try BillSplit.proportionally(10, weights: ["anna": 1, "bela": 2, "cili": 4], among: trio) == ["anna": 1, "bela": 3, "cili": 6])
    }

    @Test func zeroWeightPaysNothing() throws {
        let shares = try BillSplit.proportionally(101, weights: ["bela": 1, "cili": 1], among: trio)
        #expect(shares == ["anna": 0, "bela": 51, "cili": 50])
    }

    @Test func refundsMirrorCharges() throws {
        let charge = try BillSplit.equally(1000, among: trio)
        #expect(try BillSplit.equally(-1000, among: trio) == charge.mapValues { -$0 })
        let items = [item(700, ["anna", "bela"]), item(333, ["bela", "cili"])]
        let refund = items.map { item(-$0.amountMinor, $0.sharedBy) }
        let itemized = try BillSplit.byItem(1200, items: items, among: trio)
        #expect(try BillSplit.byItem(-1200, items: refund, among: trio) == itemized.mapValues { -$0 })
    }

    @Test func exactSharesMustAddUp() throws {
        #expect(try BillSplit.exactly(1000, shares: ["anna": 600, "bela": 400], among: trio) == ["anna": 600, "bela": 400, "cili": 0])
        #expect(throws: BillSplitError.doesNotAddUp(missingMinor: 100)) {
            try BillSplit.exactly(1000, shares: ["anna": 900], among: trio)
        }
        #expect(throws: BillSplitError.doesNotAddUp(missingMinor: -1)) {
            try BillSplit.exactly(1000, shares: ["anna": 1001], among: trio)
        }
    }

    @Test func tipFollowsWhatEachPersonHad() throws {
        let items = [item(3000, ["anna"]), item(1000, ["bela"])]
        #expect(try BillSplit.byItem(4400, items: items, among: trio) == ["anna": 3300, "bela": 1100, "cili": 0])
    }

    @Test func discountsComeOffInProportion() throws {
        let items = [item(3000, ["anna"]), item(1000, ["bela"])]
        #expect(try BillSplit.byItem(3600, items: items, among: trio) == ["anna": 2700, "bela": 900, "cili": 0])
    }

    @Test func withoutItemsTheExtraIsSplitEqually() throws {
        #expect(try BillSplit.byItem(1000, items: [], among: trio) == ["anna": 334, "bela": 333, "cili": 333])
    }

    @Test func badInputIsRefused() {
        #expect(throws: BillSplitError.noParticipants) { try BillSplit.equally(1, among: []) }
        #expect(throws: BillSplitError.duplicateParticipant) { try BillSplit.equally(1, among: ["anna", "anna"]) }
        #expect(throws: BillSplitError.unknownParticipant) { try BillSplit.exactly(1, shares: ["dora": 1], among: trio) }
        #expect(throws: BillSplitError.unknownParticipant) { try BillSplit.byItem(1, items: [item(1, ["dora"])], among: trio) }
        #expect(throws: BillSplitError.itemWithoutPeople(itemID: "item")) { try BillSplit.byItem(1, items: [item(1, [])], among: trio) }
        #expect(throws: BillSplitError.negativeWeight) { try BillSplit.proportionally(1, weights: ["anna": -1], among: trio) }
        #expect(throws: BillSplitError.noWeight) { try BillSplit.proportionally(1, weights: [:], among: trio) }
        #expect(throws: BillSplitError.amountTooLarge) {
            try BillSplit.byItem(0, items: [item(.max, ["anna"]), item(.max, ["bela"])], among: trio)
        }
    }

    @Test(arguments: [Int64.max, Int64.min])
    func hugeTotalsStayExact(total: Int64) throws {
        #expect(try BillSplit.equally(total, among: ["anna"]) == ["anna": total])
        let shares = try BillSplit.proportionally(total, weights: ["anna": .max, "bela": .max - 1], among: trio)
        #expect(shares.values.reduce(0, +) == total)
    }

    @Test func everySplitAddsUpAndIsFair() throws {
        var random = SeededGenerator(state: 42)
        for _ in 0..<2000 {
            let people = (0..<Int.random(in: 1...12, using: &random)).map { "p\($0)" }
            let total = Int64.random(in: -1_000_000...1_000_000, using: &random)

            let equal = try BillSplit.equally(total, among: people)
            #expect(equal.values.reduce(0, +) == total)
            let spread = (equal.values.max() ?? 0) - (equal.values.min() ?? 0)
            #expect(spread <= 1)

            let items = (0..<Int.random(in: 0...8, using: &random)).map { _ in
                let sharers = people.shuffled(using: &random).prefix(Int.random(in: 1...people.count, using: &random))
                return item(Int64.random(in: -500...5000, using: &random), Set(sharers))
            }
            let itemized = try BillSplit.byItem(total, items: items, among: people)
            #expect(itemized.values.reduce(0, +) == total)
            #expect(Set(itemized.keys) == Set(people))
        }
    }
}

/// Repeatable randomness (SplitMix64), so a failure can be reproduced.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
