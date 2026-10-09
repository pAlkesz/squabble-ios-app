import Foundation

/// A Hungarian domestic account number ("számlaszám"): 16 or 24 digits, written in
/// blocks of eight. It maps exactly onto a Hungarian IBAN — the IBAN is "HU", two mod-97
/// check digits, then the number padded to 24 digits — so it's only ever stored as one.
/// Each part carries its own check digit (weights 9, 7, 3, 1), which catches most typos
/// before the IBAN's check even comes into it.
nonisolated struct HungarianAccountNumber: Hashable, Sendable {
    /// Always 24 digits; a 16-digit number is padded with eight zeros, as in its IBAN.
    let digits: String

    init(validating input: String) throws(HungarianAccountNumberError) {
        let digits = input.filter { !$0.isWhitespace && $0 != "-" }
        guard digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw .invalidFormat }
        guard digits.count == 16 || digits.count == 24 else { throw .wrongLength }
        // The bank and branch code, then the account itself (8 or 16 digits).
        guard Self.isValidPart(digits.prefix(8)), Self.isValidPart(digits.dropFirst(8)) else {
            throw .checksumMismatch
        }
        self.digits = digits.count == 16 ? digits + "00000000" : digits
    }

    /// Nil for any IBAN that isn't Hungarian.
    init?(iban: IBAN) {
        guard iban.value.hasPrefix("HU"), iban.value.count == 28 else { return nil }
        digits = String(iban.value.dropFirst(4))
    }

    var iban: IBAN? {
        let checkDigits = 98 - IBAN.remainder(of: "\(digits)HU00")
        return try? IBAN(validating: "HU\(String(format: "%02d", checkDigits))\(digits)")
    }

    /// Blocks of eight joined by hyphens, dropping the padding of a 16-digit number.
    var formatted: String {
        let significant = digits.hasSuffix("00000000") ? String(digits.prefix(16)) : digits
        return stride(from: 0, to: significant.count, by: 8).map { offset in
            let start = significant.index(significant.startIndex, offsetBy: offset)
            return String(significant[start..<significant.index(start, offsetBy: 8)])
        }
        .joined(separator: "-")
    }

    private static func isValidPart(_ part: Substring) -> Bool {
        let values = part.compactMap(\.wholeNumberValue)
        guard let check = values.last else { return false }
        let weights = [9, 7, 3, 1]
        let sum = values.dropLast().enumerated().reduce(0) { $0 + $1.element * weights[$1.offset % 4] }
        return (10 - sum % 10) % 10 == check
    }
}

nonisolated enum HungarianAccountNumberError: LocalizedError, Equatable {
    case wrongLength
    case invalidFormat
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .wrongLength:
            String(localized: "A Hungarian account number has 16 or 24 digits.")
        case .invalidFormat:
            String(localized: "Account numbers are digits only — or paste an IBAN instead.")
        case .checksumMismatch:
            String(localized: "That account number doesn't add up. Check for a typo.")
        }
    }
}
