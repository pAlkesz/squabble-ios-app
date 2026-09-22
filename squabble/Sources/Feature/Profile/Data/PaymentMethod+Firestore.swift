import Foundation

/// Payment methods live together in `users/{uid}/private/payment` as a `methods` array:
/// one document read instead of one per method.
nonisolated extension PaymentMethod {
    /// Unreadable entries are skipped rather than failing the whole list.
    init?(firestoreData data: [String: Any]) {
        guard let id = data["id"] as? String else { return nil }
        switch data["kind"] as? String {
        case "bankAccount":
            guard let iban = (data["iban"] as? String).flatMap({ try? IBAN(validating: $0) }),
                  let holderName = data["holderName"] as? String
            else { return nil }
            self.init(id: id, kind: .bankAccount(iban: iban, holderName: holderName))
        case "link":
            guard let provider = (data["provider"] as? String).flatMap(PaymentProvider.init(rawValue:)),
                  let username = data["username"] as? String,
                  let link = try? PaymentLink(provider: provider, input: username)
            else { return nil }
            self.init(id: id, kind: .link(link))
        default:
            return nil
        }
    }

    var firestoreData: [String: Any] {
        switch kind {
        case .bankAccount(let iban, let holderName):
            ["id": id, "kind": "bankAccount", "iban": iban.value, "holderName": holderName]
        case .link(let link):
            ["id": id, "kind": "link", "provider": link.provider.rawValue, "username": link.username]
        }
    }
}
