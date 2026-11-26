import Foundation

/// The latest thing that happened in a squabble, copied onto the group document by whoever
/// did it, so the squabble lists can say it without reading the chat. Stored as what
/// happened, not as a sentence, so each reader sees it in their own language.
nonisolated struct SquabbleActivity: Equatable, Sendable {
    enum Kind: String, Sendable {
        case message
        case messageDeleted
        case billAdded
        case billEdited
        case billDeleted
    }

    static let maxTextLength = 120

    let kind: Kind
    /// The uid of whoever did it.
    let by: String
    /// The message's or the bill's id.
    let id: String
    /// The message's text or the bill's title; nil for a deleted message.
    let text: String?

    init(kind: Kind, by: String, id: String, text: String? = nil) {
        self.kind = kind
        self.by = by
        self.id = id
        self.text = text.map { String($0.prefix(Self.maxTextLength)) }
    }

    static func message(_ message: ChatMessage) -> SquabbleActivity {
        SquabbleActivity(kind: .message, by: message.authorID, id: message.id, text: message.text)
    }

    static func bill(_ kind: Kind, _ bill: Bill, by uid: String) -> SquabbleActivity {
        SquabbleActivity(kind: kind, by: uid, id: bill.id, text: bill.title)
    }
}

nonisolated extension SquabbleActivity {
    enum Field {
        static let kind = "kind"
        static let by = "by"
        static let id = "id"
        static let text = "text"
    }

    /// A kind this app doesn't know yet reads as nothing, so the row falls back to its
    /// placeholder rather than guessing.
    init?(firestoreData data: [String: Any]) {
        guard let kind = (data[Field.kind] as? String).flatMap(Kind.init(rawValue:)),
              let by = data[Field.by] as? String,
              let id = data[Field.id] as? String
        else { return nil }
        self.init(kind: kind, by: by, id: id, text: data[Field.text] as? String)
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [Field.kind: kind.rawValue, Field.by: by, Field.id: id]
        if let text { data[Field.text] = text }
        return data
    }
}
