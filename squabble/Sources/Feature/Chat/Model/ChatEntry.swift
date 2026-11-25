import Foundation

/// One thing in a squabble's timeline.
nonisolated enum ChatEntry: Identifiable, Equatable, Sendable {
    case message(ChatMessage)
    case bill(Bill)

    var id: String {
        switch self {
        case .message(let message): message.id
        case .bill(let bill): bill.id
        }
    }

    var createdAt: Date? {
        switch self {
        case .message(let message): message.createdAt
        case .bill(let bill): bill.createdAt
        }
    }

    /// Both feeds in one, oldest first. Where one has been loaded further back than the other,
    /// it waits for it, so nothing turns up later in the middle of what's been read.
    static func merged(_ messages: PagedFeed<ChatMessage>, _ bills: PagedFeed<Bill>, now: Date = .now) -> [ChatEntry] {
        let since = [messages.loadedSince, bills.loadedSince].compactMap(\.self).max()
        let entries = messages.items.map(ChatEntry.message) + bills.items.map(ChatEntry.bill)
        return entries
            .filter { since == nil || ($0.createdAt ?? now) >= since ?? .distantPast }
            .enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.createdAt ?? now, right = rhs.element.createdAt ?? now
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }
}
