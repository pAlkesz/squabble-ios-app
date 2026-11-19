import Foundation

/// A message in a squabble's chat (docs/specs/chat.md). Text only in v1; bills and
/// settlements join the timeline from their own collections once they exist.
nonisolated struct ChatMessage: Identifiable, Equatable, Sendable {
    static let maxLength = 2000
    /// The quick reactions offered on long press.
    static let quickReactions = ["❤️", "😂", "😮", "😢", "🙄", "👍"]

    let id: String
    let authorID: String
    /// Nil only for a message whose server time hasn't been estimated yet.
    var createdAt: Date?
    var text: String
    var replyTo: ChatReply?
    /// One emoji per member, by uid.
    var reactions: [String: String] = [:]
    var deletedAt: Date?
    /// Written to the local cache but not yet to the server. A pending reaction on a sent
    /// message doesn't count.
    var isPending = false

    var isDeleted: Bool { deletedAt != nil }

    /// Reactions grouped for the chips under the message: most used first, then in the
    /// order of the quick reactions, so the chips don't jump around.
    var reactionCounts: [(emoji: String, count: Int)] {
        let counts = Dictionary(grouping: reactions.values, by: { $0 }).mapValues(\.count)
        return counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            let order = { (emoji: String) in Self.quickReactions.firstIndex(of: emoji) ?? Int.max }
            if order(lhs.key) != order(rhs.key) { return order(lhs.key) < order(rhs.key) }
            return lhs.key < rhs.key
        }
        .map { (emoji: $0.key, count: $0.value) }
    }
}
