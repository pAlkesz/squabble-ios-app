import Foundation

/// A squabble's messages. Writes land in the local cache straight away and sync later, so
/// chatting works offline; only reading older pages needs the server.
nonisolated protocol ChatRepository: Sendable {
    /// The latest `limit` messages, oldest first, from the cache and then every change.
    func latestMessages(in groupID: String, limit: Int) -> AsyncThrowingStream<[ChatMessage], Error>
    /// Up to `limit` messages from before `date`, oldest first.
    func messages(in groupID: String, before date: Date, limit: Int) async throws -> [ChatMessage]
    func send(_ message: ChatMessage, in groupID: String) throws
    /// Sets the user's reaction, or clears it with nil.
    func setReaction(_ emoji: String?, by uid: String, on messageID: String, in groupID: String) throws
    /// Author only: blanks the text and marks the message deleted.
    func delete(_ messageID: String, in groupID: String) throws
    func report(_ message: ChatMessage, in groupID: String, by uid: String) throws
    /// A fresh id, so a reply can point at a message before it's sent.
    func newMessageID(in groupID: String) -> String
}
