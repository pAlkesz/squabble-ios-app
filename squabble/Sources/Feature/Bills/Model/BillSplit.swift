/// Splits a bill into shares that always add up to its exact total (docs/specs/bills.md,
/// "Splitting"). Amounts are minor units; participants are uids, in the bill's order, which
/// decides who gets a leftover cent when there's a tie.
nonisolated enum BillSplit {
    typealias Shares = [String: Int64]

    static func equally(_ total: Int64, among participants: [String]) throws(BillSplitError) -> Shares {
        try check(participants)
        return try split(total, participants.map { ($0, 1) })
    }

    /// Checks shares entered by hand; anyone left out gets 0.
    static func exactly(_ total: Int64, shares: Shares, among participants: [String]) throws(BillSplitError) -> Shares {
        try check(participants)
        guard Set(shares.keys).isSubset(of: participants) else { throw .unknownParticipant }
        var sum: Int64 = 0
        var result: Shares = [:]
        for participant in participants {
            let share = shares[participant] ?? 0
            sum = try add(sum, share)
            result[participant] = share
        }
        guard sum == total else { throw .doesNotAddUp(missingMinor: try subtract(total, sum)) }
        return result
    }

    /// The people to split among in an order of the bill's own, so the leftover cents don't
    /// always land on the same ones. By uid first, so every phone starts from the same order.
    static func rotated(_ participants: [String], by billID: String) -> [String] {
        guard !participants.isEmpty else { return [] }
        let sorted = participants.sorted()
        // FNV-1a: Swift's own hashes differ between launches.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in billID.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        let start = Int(hash % UInt64(sorted.count))
        return Array(sorted[start...] + sorted[..<start])
    }

    static func proportionally(_ total: Int64, weights: Shares, among participants: [String]) throws(BillSplitError) -> Shares {
        try check(participants)
        guard Set(weights.keys).isSubset(of: participants) else { throw .unknownParticipant }
        var pairs: [(String, UInt64)] = []
        for participant in participants {
            let weight = weights[participant] ?? 0
            guard weight >= 0 else { throw .negativeWeight }
            pairs.append((participant, UInt64(weight)))
        }
        return try split(total, pairs)
    }

    /// Each item equally among those who had it. Whatever the total has beyond the items
    /// (tax and tip, or a discount) goes in proportion to what each person had.
    static func byItem(_ total: Int64, items: [BillItem], among participants: [String]) throws(BillSplitError) -> Shares {
        try check(participants)
        let known = Set(participants)
        var result = Shares(uniqueKeysWithValues: participants.map { ($0, 0) })
        var itemsTotal: Int64 = 0
        for item in items {
            guard item.sharedBy.isSubset(of: known) else { throw .unknownParticipant }
            let people = participants.filter(item.sharedBy.contains)
            guard !people.isEmpty else { throw .itemWithoutPeople(itemID: item.id) }
            itemsTotal = try add(itemsTotal, item.amountMinor)
            result = try merge(result, equally(item.amountMinor, among: people))
        }
        let extra = try subtract(total, itemsTotal)
        guard extra != 0 else { return result }

        // On a refund the subtotals are negative; their size is what counts, so its shares
        // mirror the charge's.
        var weights: [(String, UInt64)] = []
        for participant in participants {
            let subtotal = result[participant] ?? 0
            let counts = itemsTotal < 0 ? subtotal < 0 : subtotal > 0
            weights.append((participant, counts ? subtotal.magnitude : 0))
        }
        let nobodyHadAnything = weights.allSatisfy { $0.1 == 0 }
        return try merge(result, nobodyHadAnything ? equally(extra, among: participants) : split(extra, weights))
    }

    /// The leftover cents rule: everyone's share truncated, then one unit each to the largest
    /// remainders. Integers throughout, so remainders compare exactly. Splits the magnitude
    /// and restores the sign.
    private static func split(_ total: Int64, _ weights: [(participant: String, weight: UInt64)]) throws(BillSplitError) -> Shares {
        var weightSum: UInt64 = 0
        for entry in weights {
            let (sum, overflow) = weightSum.addingReportingOverflow(entry.weight)
            guard !overflow else { throw .amountTooLarge }
            weightSum = sum
        }
        guard weightSum > 0 else { throw .noWeight }

        // No weight exceeds the sum, so a quotient never exceeds the total and always fits.
        var parts: [(index: Int, quotient: UInt64, remainder: UInt64)] = []
        var leftover = total.magnitude
        for (index, entry) in weights.enumerated() {
            let (quotient, remainder) = weightSum.dividingFullWidth(total.magnitude.multipliedFullWidth(by: entry.weight))
            parts.append((index, quotient, remainder))
            leftover -= quotient
        }
        parts.sort { $0.remainder != $1.remainder ? $0.remainder > $1.remainder : $0.index < $1.index }

        var result: Shares = [:]
        for (rank, part) in parts.enumerated() {
            let magnitude = part.quotient + (UInt64(rank) < leftover ? 1 : 0)
            result[weights[part.index].participant] = try signed(magnitude, isNegative: total < 0)
        }
        return result
    }

    private static func signed(_ magnitude: UInt64, isNegative: Bool) throws(BillSplitError) -> Int64 {
        guard magnitude <= Int64.max.magnitude else {
            guard isNegative, magnitude == Int64.min.magnitude else { throw .amountTooLarge }
            return .min
        }
        return isNegative ? -Int64(magnitude) : Int64(magnitude)
    }

    private static func check(_ participants: [String]) throws(BillSplitError) {
        guard !participants.isEmpty else { throw .noParticipants }
        guard Set(participants).count == participants.count else { throw .duplicateParticipant }
    }

    private static func merge(_ shares: Shares, _ other: Shares) throws(BillSplitError) -> Shares {
        var result = shares
        for (participant, share) in other {
            result[participant] = try add(result[participant] ?? 0, share)
        }
        return result
    }

    private static func add(_ lhs: Int64, _ rhs: Int64) throws(BillSplitError) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw .amountTooLarge }
        return sum
    }

    private static func subtract(_ lhs: Int64, _ rhs: Int64) throws(BillSplitError) -> Int64 {
        let (difference, overflow) = lhs.subtractingReportingOverflow(rhs)
        guard !overflow else { throw .amountTooLarge }
        return difference
    }
}
