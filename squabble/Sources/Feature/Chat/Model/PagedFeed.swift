import Foundation

nonisolated protocol FeedItem: Identifiable, Equatable, Sendable where ID == String {
    var createdAt: Date? { get }
}

extension ChatMessage: FeedItem {}
extension Bill: FeedItem {}

/// The latest page live, with older pages joined on above it.
nonisolated struct PagedFeed<Item: FeedItem>: Equatable {
    private(set) var items: [Item] = []
    private(set) var hasLoaded = false
    /// The server has answered since the last time the connection dropped.
    private(set) var isLive = false
    private var isLatestFull = false
    private var hasReachedStart = false

    var canLoadOlder: Bool { isLatestFull && !hasReachedStart }

    /// Nothing before this has been loaded, though there may be some; nil when there isn't.
    var loadedSince: Date? {
        canLoadOlder ? items.first?.createdAt : nil
    }

    /// Puts the live page after what's already loaded: it wins where they overlap (it has the
    /// latest changes), and what it has moved past stays above it.
    mutating func show(latest page: FeedPage<Item>) {
        hasLoaded = true
        isLive = !page.isFromCache
        isLatestFull = page.isFull
        if !page.isFromCache, !page.isFull {
            // Everything the server has fits in one page.
            items = page.items
            hasReachedStart = true
        } else if let first = page.items.first, let index = items.firstIndex(where: { $0.id == first.id }) {
            items = items[..<index] + page.items
        } else {
            // No overlap at its start: there may be some in between (a long time offline), so
            // start over rather than leave a silent hole.
            items = page.items
            hasReachedStart = false
        }
    }

    mutating func add(older page: FeedPage<Item>, before oldest: Item) {
        // The live page started over meanwhile, so this one no longer joins on.
        guard items.first?.id == oldest.id else { return }
        let known = Set(items.map(\.id))
        items = page.items.filter { !known.contains($0.id) } + items
        // The cache only holds what this phone has seen, so it can't say where it starts.
        if !page.isFromCache, !page.isFull { hasReachedStart = true }
    }

    /// The listener is gone; show what there is.
    mutating func fail() {
        hasLoaded = true
    }
}
