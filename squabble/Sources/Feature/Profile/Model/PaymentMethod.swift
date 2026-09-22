import Foundation

/// One way to get paid back. Only the owner can read these; they'll be shared into a
/// group's member entry once groups exist.
nonisolated struct PaymentMethod: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case bankAccount(iban: IBAN, holderName: String)
        case link(PaymentLink)
    }

    static let maxCount = 5

    let id: String
    var kind: Kind

    init(id: String = UUID().uuidString, kind: Kind) {
        self.id = id
        self.kind = kind
    }
}
