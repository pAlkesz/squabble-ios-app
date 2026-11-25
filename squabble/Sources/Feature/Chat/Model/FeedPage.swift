/// A stretch of a squabble's messages or bills, oldest first.
nonisolated struct FeedPage<Item: FeedItem>: Equatable, Sendable {
    let items: [Item]
    /// As many documents as were asked for, counting any this app can't show.
    let isFull: Bool
    /// Answered from this phone's cache, which may be missing some.
    let isFromCache: Bool
}
