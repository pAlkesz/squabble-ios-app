import Foundation

/// Everything entered on the new-squabble screen, before anything is saved.
nonisolated struct NewSquabbleDraft: Equatable {
    enum AddOutcome: Equatable {
        case added
        case isCreator
        case alreadyAdded
        case full
    }

    let creator: UserProfile
    var name = ""
    var currencyCode: String
    /// Everyone but the creator, in the order they were added.
    private(set) var members: [UserProfile] = []

    init(creator: UserProfile, currencyCode: String) {
        self.creator = creator
        self.currencyCode = currencyCode
    }

    var memberCount: Int { members.count + 1 }

    var validName: String? {
        SquabbleGroup.validName(name)
    }

    var canCreate: Bool {
        validName != nil
    }

    mutating func setName(_ input: String) {
        name = String(input.prefix(SquabbleGroup.maxNameLength))
    }

    @discardableResult
    mutating func add(_ profile: UserProfile) -> AddOutcome {
        guard profile.id != creator.id else { return .isCreator }
        guard !members.contains(where: { $0.id == profile.id }) else { return .alreadyAdded }
        guard memberCount < SquabbleGroup.maxMembers else { return .full }
        members.append(profile)
        return .added
    }

    mutating func remove(_ uid: String) {
        members.removeAll { $0.id == uid }
    }

    /// The group to save, with the creator first. Only the creator's payment details are
    /// known here; everyone else copies theirs in when they next open the app.
    func makeGroup(id: String, creatorPaymentMethods: [PaymentMethod]) -> SquabbleGroup? {
        guard let name = validName else { return nil }
        let entries = [GroupMember(profile: creator, paymentMethods: creatorPaymentMethods)]
            + members.map { GroupMember(profile: $0) }
        return SquabbleGroup(
            id: id,
            name: name,
            currencyCode: currencyCode,
            createdBy: creator.id,
            memberIds: entries.map(\.id),
            members: Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        )
    }
}
