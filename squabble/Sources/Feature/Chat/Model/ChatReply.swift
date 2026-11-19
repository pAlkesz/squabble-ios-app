import Foundation

/// The message a reply quotes, copied into the reply so showing it never needs a read.
nonisolated struct ChatReply: Equatable, Sendable {
    static let maxPreviewLength = 120

    let messageID: String
    let authorID: String
    let preview: String

    init(messageID: String, authorID: String, preview: String) {
        self.messageID = messageID
        self.authorID = authorID
        self.preview = String(preview.prefix(Self.maxPreviewLength))
    }

    init(quoting message: ChatMessage) {
        self.init(messageID: message.id, authorID: message.authorID, preview: message.text)
    }
}
