import Foundation

/// Groups a bank account number as it's typed, the way banks print it: an IBAN in blocks
/// of four, a Hungarian domestic number in blocks of eight joined by hyphens. Separators
/// only appear once something follows them, so deleting back over one just works.
/// Formatting only — validation stays with `IBAN(validatingAccountNumber:)`.
nonisolated enum BankAccountNumberFormatter {
    static func format(_ input: String) -> String {
        let compact = input.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        // Letters up front mean an IBAN, as in `IBAN(validatingAccountNumber:)`.
        if compact.first?.isLetter ?? false {
            return grouped(String(compact.prefix(IBAN.lengthRange.upperBound)), by: 4, separator: " ")
        }
        return grouped(String(compact.filter(\.isNumber).prefix(24)), by: 8, separator: "-")
    }

    private static func grouped(_ text: String, by size: Int, separator: String) -> String {
        stride(from: 0, to: text.count, by: size).map { offset in
            let start = text.index(text.startIndex, offsetBy: offset)
            let end = text.index(start, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex
            return String(text[start..<end])
        }
        .joined(separator: separator)
    }
}
