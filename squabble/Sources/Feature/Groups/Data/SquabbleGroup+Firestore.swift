import Foundation

/// Mapping to and from `groups/{id}`. Kept free of Firebase types so it can be tested
/// without the SDK; the adapter converts timestamps to `Date` before reading and adds
/// server timestamps when writing.
nonisolated extension SquabbleGroup {
    enum Field {
        static let name = "name"
        static let currency = "currency"
        static let image = "image"
        static let createdBy = "createdBy"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let archivedAt = "archivedAt"
        static let memberIds = "memberIds"
        static let members = "members"
    }

    init(id: String, firestoreData data: [String: Any]) throws(FirestoreMappingError) {
        guard let name = data[Field.name] as? String,
              let currencyCode = data[Field.currency] as? String,
              let createdBy = data[Field.createdBy] as? String,
              let memberIds = data[Field.memberIds] as? [String]
        else { throw .malformed("groups/\(id)") }
        let entries = data[Field.members] as? [String: Any] ?? [:]
        var members: [String: GroupMember] = [:]
        for (uid, entry) in entries {
            guard let entry = entry as? [String: Any] else { continue }
            members[uid] = GroupMember(id: uid, firestoreData: entry)
        }
        self.init(
            id: id,
            name: name,
            currencyCode: currencyCode,
            image: (data[Field.image] as? [String: Any]).flatMap(SquabbleImage.init(firestoreData:))
                ?? .default(for: id),
            createdBy: createdBy,
            createdAt: data[Field.createdAt] as? Date,
            updatedAt: data[Field.updatedAt] as? Date,
            archivedAt: data[Field.archivedAt] as? Date,
            memberIds: memberIds,
            members: members
        )
    }

    /// Timestamps (the group's and each member's `joinedAt`) are left to the caller.
    var firestoreData: [String: Any] {
        [
            Field.name: name,
            Field.currency: currencyCode,
            Field.image: image.firestoreData,
            Field.createdBy: createdBy,
            Field.memberIds: memberIds,
            Field.members: members.mapValues(\.firestoreData),
        ]
    }
}

nonisolated extension GroupMember {
    enum Field {
        static let displayName = "displayName"
        static let handle = "handle"
        static let avatar = "avatar"
        static let payment = "payment"
        static let joinedAt = "joinedAt"
        static let leftAt = "leftAt"
        static let deleted = "deleted"
    }

    /// Never fails: an entry that can't be read still stands for someone in old bills, so
    /// missing pieces fall back to the default bird and an empty name.
    init(id: String, firestoreData data: [String: Any]) {
        let avatarData = data[Field.avatar] as? [String: Any] ?? [:]
        let payment = data[Field.payment] as? [[String: Any]] ?? []
        self.init(
            id: id,
            displayName: data[Field.displayName] as? String ?? "",
            handle: (data[Field.handle] as? String).flatMap { try? Handle(validating: $0) },
            avatar: Avatar(firestoreData: avatarData) ?? .preset(.default(for: id)),
            paymentMethods: payment.compactMap(PaymentMethod.init(firestoreData:)),
            joinedAt: data[Field.joinedAt] as? Date,
            leftAt: data[Field.leftAt] as? Date,
            isDeleted: data[Field.deleted] as? Bool ?? false
        )
    }

    /// The profile copy only; `joinedAt`/`leftAt`/`deleted` are written by whoever changes them.
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            Field.displayName: displayName,
            Field.avatar: avatar.firestoreData,
            Field.payment: paymentMethods.map(\.firestoreData),
        ]
        if let handle { data[Field.handle] = handle.rawValue }
        return data
    }
}

nonisolated extension SquabbleImage {
    init?(firestoreData data: [String: Any]) {
        switch data["kind"] as? String {
        case "emoji":
            guard let emoji = data["emoji"] as? String, !emoji.isEmpty,
                  let color = (data["color"] as? String).flatMap(AvatarColor.init(rawValue:))
            else { return nil }
            self = .emoji(emoji, color)
        case "photo":
            guard let path = data["path"] as? String,
                  let url = (data["url"] as? String).flatMap(URL.init(string:))
            else { return nil }
            self = .photo(path: path, url: url)
        default:
            return nil
        }
    }

    var firestoreData: [String: Any] {
        switch self {
        case .emoji(let emoji, let color):
            ["kind": "emoji", "emoji": emoji, "color": color.rawValue]
        case .photo(let path, let url):
            ["kind": "photo", "path": path, "url": url.absoluteString]
        }
    }
}
