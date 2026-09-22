import Foundation

/// An International Bank Account Number, stored without spaces in upper case.
/// Validated with the ISO 13616 mod-97 check, which catches virtually every typo and
/// swapped digit — it can't tell whether the account actually exists.
nonisolated struct IBAN: Hashable, Sendable {
    static let lengthRange = 15...34

    let value: String

    init(validating input: String) throws(IBANError) {
        let value = input.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard Self.lengthRange.contains(value.count) else { throw .wrongLength }
        let scalars = Array(value.unicodeScalars)
        guard scalars.allSatisfy(Self.isAlphanumeric),
              scalars[0...1].allSatisfy(Self.isLetter),
              scalars[2...3].allSatisfy(Self.isDigit)
        else { throw .invalidFormat }
        guard Self.checksum(of: scalars) == 1 else { throw .checksumMismatch }
        self.value = value
    }

    /// Groups of four, the way banks print it.
    var formatted: String {
        stride(from: 0, to: value.count, by: 4).map { offset in
            let start = value.index(value.startIndex, offsetBy: offset)
            let end = value.index(start, offsetBy: 4, limitedBy: value.endIndex) ?? value.endIndex
            return String(value[start..<end])
        }
        .joined(separator: " ")
    }

    private static func checksum(of scalars: [Unicode.Scalar]) -> Int {
        let rearranged = scalars[4...] + scalars[..<4]
        var remainder = 0
        for scalar in rearranged {
            // Letters count as two digits (A = 10 … Z = 35), so shift by 100 instead of 10.
            if isDigit(scalar) {
                remainder = (remainder * 10 + Int(scalar.value - 48)) % 97
            } else {
                remainder = (remainder * 100 + Int(scalar.value - 55)) % 97
            }
        }
        return remainder
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool { ("A"..."Z").contains(scalar) }
    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool { ("0"..."9").contains(scalar) }
    private static func isAlphanumeric(_ scalar: Unicode.Scalar) -> Bool { isLetter(scalar) || isDigit(scalar) }
}

nonisolated enum IBANError: LocalizedError, Equatable {
    case wrongLength
    case invalidFormat
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .wrongLength:
            String(localized: "That's not the right length for an IBAN.")
        case .invalidFormat:
            String(localized: "An IBAN starts with a country code, like HU or DE.")
        case .checksumMismatch:
            String(localized: "That IBAN doesn't add up. Check for a typo.")
        }
    }
}
