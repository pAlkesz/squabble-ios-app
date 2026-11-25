import Foundation

/// Everything on the bill form, for a new bill or an edit.
nonisolated struct BillDraft: Identifiable, Equatable {
    let id: String
    let currencyCode: String
    /// Who can pay and share: the current members, and on an edit anyone already on the bill.
    let candidates: [String]
    private let original: Bill?
    private(set) var amountText = ""
    private(set) var title = ""
    var paidBy: String
    var date: CalendarDay
    private(set) var split: Bill.Split = .equally
    private(set) var included: Set<String>
    private(set) var exactTexts: [String: String] = [:]

    init(newBillIn group: SquabbleGroup, by uid: String, id: String = UUID().uuidString, today: CalendarDay = CalendarDay(.now)) {
        self.id = id
        currencyCode = group.currencyCode
        candidates = group.currentMembers.map(\.id)
        original = nil
        paidBy = uid
        date = today
        included = Set(candidates)
    }

    init(editing bill: Bill, in group: SquabbleGroup) {
        id = bill.id
        currencyCode = bill.currencyCode
        let current = group.currentMembers.map(\.id)
        let former = Set(bill.shares.keys).union([bill.paidBy]).subtracting(current)
        candidates = current + former.sorted()
        original = bill
        amountText = AmountInput.text(for: bill.total)
        title = bill.title
        paidBy = bill.paidBy
        date = bill.date
        split = bill.split
        included = Set(bill.shares.keys)
        if bill.split == .exactly {
            exactTexts = bill.shares.filter { $0.value != 0 }.mapValues {
                AmountInput.text(for: Money(minorUnits: $0, currencyCode: bill.currencyCode))
            }
        }
    }

    var isNew: Bool { original == nil }

    mutating func setAmount(_ input: String) {
        amountText = AmountInput.sanitized(input, currencyCode: currencyCode)
    }

    mutating func setTitle(_ input: String) {
        title = String(input.prefix(Bill.maxTitleLength))
    }

    mutating func setExact(_ input: String, for uid: String) {
        exactTexts[uid] = AmountInput.sanitized(input, currencyCode: currencyCode)
    }

    mutating func toggle(_ uid: String) {
        if included.contains(uid) { included.remove(uid) } else { included.insert(uid) }
    }

    /// Going to exact amounts starts from the equal split, so there's only the difference to
    /// type.
    mutating func setSplit(_ split: Bill.Split) {
        guard split != self.split else { return }
        if split == .exactly, let shares = try? equalShares() {
            exactTexts = shares.filter { $0.value != 0 }.mapValues {
                AmountInput.text(for: Money(minorUnits: $0, currencyCode: currencyCode))
            }
        }
        self.split = split
    }

    /// Nil until there's an amount the server would take.
    var total: Money? {
        guard let money = AmountInput.money(from: amountText, currencyCode: currencyCode),
              money.minorUnits > 0, money.minorUnits <= Bill.maxTotalMinor
        else { return nil }
        return money
    }

    var validTitle: String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var includesEveryone: Bool { included.isSuperset(of: candidates) }

    /// The shares, or nil while the split doesn't work out (see `missing`).
    var shares: [String: Int64]? {
        switch split {
        case .equally:
            return try? equalShares()
        case .exactly:
            guard let total else { return nil }
            let people = candidates.filter { exactMinor($0) != 0 }
            let exact = Dictionary(uniqueKeysWithValues: people.map { ($0, exactMinor($0)) })
            return try? BillSplit.exactly(total.minorUnits, shares: exact, among: people)
        }
    }

    /// With exact amounts, the total minus what's assigned; negative is too much.
    var missing: Money? {
        guard split == .exactly, let total else { return nil }
        let assigned = candidates.reduce(Int64(0)) { $0 + exactMinor($1) }
        return Money(minorUnits: total.minorUnits - assigned, currencyCode: currencyCode)
    }

    /// What saving would do to someone's balance.
    func effect(on uid: String) -> Money? {
        guard let total, let shares else { return nil }
        return Money(minorUnits: (paidBy == uid ? total.minorUnits : 0) - (shares[uid] ?? 0), currencyCode: currencyCode)
    }

    var canSave: Bool { makeBill(by: "") != nil }

    func makeBill(by uid: String) -> Bill? {
        guard let total, let title = validTitle, let shares else { return nil }
        return Bill(
            id: id,
            title: title,
            date: date,
            currencyCode: currencyCode,
            totalMinor: total.minorUnits,
            paidBy: paidBy,
            split: split,
            shares: shares,
            createdBy: original?.createdBy ?? uid,
            createdAt: original?.createdAt,
            updatedBy: uid
        )
    }

    private func equalShares() throws(BillSplitError) -> [String: Int64]? {
        guard let total else { return nil }
        let people = BillSplit.rotated(candidates.filter(included.contains), by: id)
        return try BillSplit.equally(total.minorUnits, among: people)
    }

    private func exactMinor(_ uid: String) -> Int64 {
        guard let text = exactTexts[uid] else { return 0 }
        // Twelve digits each, so even fifty of them can't overflow.
        return AmountInput.money(from: text, currencyCode: currencyCode)?.minorUnits ?? 0
    }
}
