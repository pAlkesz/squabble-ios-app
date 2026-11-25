/// A stretch of a chat, oldest first.
nonisolated struct ChatPage: Equatable, Sendable {
    let messages: [ChatMessage]
    /// As many documents as were asked for, counting any this app can't show.
    let isFull: Bool
    /// Answered from this phone's cache, which may be missing messages.
    let isFromCache: Bool
}
