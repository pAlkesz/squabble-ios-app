import Foundation

/// A squabble: the people who share bills, and the currency their balances are shown in.
/// Called a group in code and in Firestore (`groups/{id}`), a squabble in the UI.
/// See docs/specs/groups.md.
nonisolated struct SquabbleGroup: Identifiable, Equatable, Sendable {
    static let maxNameLength = 50
    /// Every member lives in the group document, which keeps it small and the rules cheap.
    static let maxMembers = 50

    let id: String
    var name: String
    /// ISO 4217. The currency balances are shown and settled in; bills keep their own.
    var currencyCode: String
    /// Squabbles saved before pictures existed read as `SquabbleImage.default(for:)`.
    var image: SquabbleImage = .artwork(.trio, .mint)
    /// Holds the creator's powers (archive, delete, remove members). Passes to the
    /// earliest-joined member when the creator goes.
    var createdBy: String
    var createdAt: Date?
    var updatedAt: Date?
    var archivedAt: Date?
    /// Current members, in the order they joined; drives the rules and the home query.
    var memberIds: [String]
    /// Current, former and deleted members, by uid.
    var members: [String: GroupMember]
    /// Minted by the server when the squabble reaches it; see `InviteLink`.
    var inviteCode: String?
    /// Minor units of `currencyCode` by uid, kept by the server; zeros are left out. Nil until
    /// the squabble's first bill.
    var balances: [String: Int64]?
    /// Nil until the first message or bill, and for squabbles from before it was kept.
    var lastActivity: SquabbleActivity?
    /// Only just created here: until the server has it, its chat and bills are refused.
    var isAwaitingServer = false

    func balance(of uid: String) -> Money {
        Money(minorUnits: balances?[uid] ?? 0, currencyCode: currencyCode)
    }

    var isArchived: Bool { archivedAt != nil }

    /// Current members in the order they joined. A member whose entry is missing or
    /// unreadable is left out rather than shown blank.
    var currentMembers: [GroupMember] {
        memberIds.compactMap { members[$0] }
    }

    /// Trims the name and rejects anything empty or too long for a row on home.
    static func validName(_ input: String) -> String? {
        let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= maxNameLength else { return nil }
        return name
    }
}
