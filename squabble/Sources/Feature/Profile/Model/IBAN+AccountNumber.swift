import Foundation

nonisolated extension IBAN {
    /// Accepts what people actually paste: an IBAN from any country, or a Hungarian
    /// domestic account number, which is converted. Letters up front mean an IBAN.
    init(validatingAccountNumber input: String) throws {
        let compact = input.filter { !$0.isWhitespace && $0 != "-" }
        if compact.first?.isLetter ?? true {
            self = try IBAN(validating: compact)
            return
        }
        guard let iban = try HungarianAccountNumber(validating: compact).iban else {
            throw HungarianAccountNumberError.checksumMismatch
        }
        self = iban
    }

    /// The way a reader in `region` would write it: the domestic number for a Hungarian
    /// account read in Hungary, the IBAN otherwise.
    func preferredFormat(for region: Locale.Region? = Locale.current.region) -> String {
        if region == .hungary, let domestic = HungarianAccountNumber(iban: self) {
            return domestic.formatted
        }
        return formatted
    }
}
