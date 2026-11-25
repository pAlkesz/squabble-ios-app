import Foundation

/// Someone paid for something, and how it's split (docs/specs/bills.md).
nonisolated struct Bill: Identifiable, Equatable, Sendable {
    enum Split: String, Sendable {
        case equally
        case exactly
    }

    static let maxTitleLength = 50
    /// The security rules' and the server's limit.
    static let maxTotalMinor: Int64 = 1_000_000_000_000

    let id: String
    var title: String
    var date: CalendarDay
    var currencyCode: String
    var totalMinor: Int64
    var paidBy: String
    var split: Split
    /// Minor units by uid; adds up to `totalMinor`.
    var shares: [String: Int64]
    var createdBy: String
    /// Nil only for a bill whose server time hasn't been estimated yet.
    var createdAt: Date?
    var updatedBy: String
    var updatedAt: Date?
    /// Deleted bills stay, so the chat can say who deleted them.
    var deletedAt: Date?
    var isPending = false

    var total: Money { Money(minorUnits: totalMinor, currencyCode: currencyCode) }
    var isDeleted: Bool { deletedAt != nil }
    var isEdited: Bool { !isDeleted && createdAt != updatedAt }

    func share(of uid: String) -> Money {
        Money(minorUnits: shares[uid] ?? 0, currencyCode: currencyCode)
    }

    /// What this bill does to someone's balance: positive means they're owed.
    func effect(on uid: String) -> Money {
        Money(minorUnits: (paidBy == uid ? totalMinor : 0) - (shares[uid] ?? 0), currencyCode: currencyCode)
    }

    /// Paying or sharing.
    func involves(_ uid: String) -> Bool {
        paidBy == uid || (shares[uid] ?? 0) != 0
    }
}
