import Foundation

/// Mapping to and from `groups/{gid}/bills/{id}`, free of Firebase types; the adapter converts
/// timestamps and adds server ones.
nonisolated extension Bill {
    enum Field {
        static let title = "title"
        static let date = "date"
        static let currency = "currency"
        static let totalMinor = "totalMinor"
        static let paidBy = "paidBy"
        static let split = "split"
        static let shares = "shares"
        static let createdBy = "createdBy"
        static let createdAt = "createdAt"
        static let updatedBy = "updatedBy"
        static let updatedAt = "updatedAt"
        static let deletedAt = "deletedAt"
    }

    init?(id: String, firestoreData data: [String: Any], isPending: Bool = false) {
        guard let title = data[Field.title] as? String,
              let date = (data[Field.date] as? String).flatMap(CalendarDay.init(rawValue:)),
              let currency = data[Field.currency] as? String,
              let total = data[Field.totalMinor] as? Int64,
              let paidBy = data[Field.paidBy] as? String,
              let shares = data[Field.shares] as? [String: Int64],
              let createdBy = data[Field.createdBy] as? String
        else { return nil }
        self.init(
            id: id,
            title: title,
            date: date,
            currencyCode: currency,
            totalMinor: total,
            paidBy: paidBy,
            // A split from a newer version still has its shares, so it edits as amounts.
            split: (data[Field.split] as? String).flatMap(Split.init(rawValue:)) ?? .exactly,
            shares: shares,
            createdBy: createdBy,
            createdAt: data[Field.createdAt] as? Date,
            updatedBy: data[Field.updatedBy] as? String ?? createdBy,
            updatedAt: data[Field.updatedAt] as? Date,
            deletedAt: data[Field.deletedAt] as? Date,
            isPending: isPending
        )
    }

    /// What an edit may change; who added it, when and in what currency stay.
    var editableFirestoreData: [String: Any] {
        [
            Field.title: title,
            Field.date: date.rawValue,
            Field.totalMinor: totalMinor,
            Field.paidBy: paidBy,
            Field.split: split.rawValue,
            Field.shares: shares,
            Field.updatedBy: updatedBy,
        ]
    }

    var firestoreData: [String: Any] {
        editableFirestoreData.merging([Field.currency: currencyCode, Field.createdBy: createdBy]) { $1 }
    }
}
