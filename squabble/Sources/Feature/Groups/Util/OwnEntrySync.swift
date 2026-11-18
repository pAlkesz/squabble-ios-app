/// Works out which of the user's groups hold an out-of-date copy of their profile or
/// payment details. Each member keeps their own entry current: the rules let a member edit
/// only their own, and nobody else can read their payment details to copy them in.
nonisolated enum OwnEntrySync {
    struct Update: Equatable {
        let groupID: String
        let entry: GroupMember
    }

    static func updates(
        for groups: [SquabbleGroup],
        profile: UserProfile,
        paymentMethods: [PaymentMethod]
    ) -> [Update] {
        groups.compactMap { group in
            // Archived squabbles are read-only for everyone.
            guard !group.isArchived,
                  group.memberIds.contains(profile.id),
                  let entry = group.members[profile.id],
                  !entry.matches(profile, paymentMethods: paymentMethods)
            else { return nil }
            var updated = entry
            updated.displayName = profile.displayName
            updated.handle = profile.handle
            updated.avatar = profile.avatar
            updated.paymentMethods = paymentMethods
            return Update(groupID: group.id, entry: updated)
        }
    }
}
