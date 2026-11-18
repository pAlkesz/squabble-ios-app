nonisolated protocol GroupRepository: Sendable {
    /// The groups `uid` is a current member of, from the cache first, then every change.
    func groupChanges(for uid: String) -> AsyncThrowingStream<[SquabbleGroup], Error>

    /// Lands in the local cache straight away and syncs when it can, so creating a squabble
    /// works offline. Only throws if the write can't be made at all.
    func createGroup(_ group: SquabbleGroup) throws

    /// Rewrites the signed-in member's own copy of their profile and payment details,
    /// keeping when they joined. Same cache-first behaviour as `createGroup`.
    func updateOwnEntry(_ member: GroupMember, in groupID: String) throws
}
