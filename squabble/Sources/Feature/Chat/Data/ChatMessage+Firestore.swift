import Foundation

/// Mapping to and from `groups/{gid}/messages/{id}`, free of Firebase types like the group
/// mapping; the adapter converts timestamps and adds server ones.
nonisolated extension ChatMessage {
    enum Field {
        static let authorID = "authorId"
        static let createdAt = "createdAt"
        static let kind = "kind"
        static let text = "text"
        static let replyTo = "replyTo"
        static let reactions = "reactions"
        static let deletedAt = "deletedAt"
    }

    /// Nil for anything this app can't show (a kind from a newer version, say).
    init?(id: String, firestoreData data: [String: Any], isPending: Bool = false) {
        guard let authorID = data[Field.authorID] as? String,
              (data[Field.kind] as? String) == "text"
        else { return nil }
        let deletedAt = data[Field.deletedAt] as? Date
        guard let text = data[Field.text] as? String ?? (deletedAt == nil ? nil : "") else { return nil }
        self.init(
            id: id,
            authorID: authorID,
            createdAt: data[Field.createdAt] as? Date,
            text: text,
            replyTo: (data[Field.replyTo] as? [String: Any]).flatMap(ChatReply.init(firestoreData:)),
            reactions: (data[Field.reactions] as? [String: Any] ?? [:]).compactMapValues { $0 as? String },
            deletedAt: deletedAt,
            isPending: isPending
        )
    }

    /// A new message; `createdAt` is left to the caller (the server's clock).
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            Field.authorID: authorID,
            Field.kind: "text",
            Field.text: text,
            Field.reactions: [String: String](),
        ]
        if let replyTo { data[Field.replyTo] = replyTo.firestoreData }
        return data
    }
}

nonisolated extension ChatReply {
    init?(firestoreData data: [String: Any]) {
        guard let id = data["id"] as? String, let authorID = data["authorId"] as? String else { return nil }
        self.init(messageID: id, authorID: authorID, preview: data["preview"] as? String ?? "")
    }

    var firestoreData: [String: Any] {
        ["id": messageID, "authorId": authorID, "preview": preview]
    }
}
