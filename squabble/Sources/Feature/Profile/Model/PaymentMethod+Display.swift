import Foundation

nonisolated extension PaymentMethod {
    /// What someone types or taps to pay: the account number in the reader's preferred
    /// format, or the payment link.
    var displayValue: String {
        switch kind {
        case .bankAccount(let iban, _): iban.preferredFormat()
        case .link(let link): link.provider.linkPrefixes[0] + link.username
        }
    }
}
