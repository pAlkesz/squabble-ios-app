import Foundation

/// A unique `@handle`, the only exact way to look someone up. Stored lowercased so
/// `@Pal` and `@pal` can't be two different people.
nonisolated struct Handle: Hashable, Sendable, CustomStringConvertible {
    static let lengthRange = 3...20

    let rawValue: String

    var description: String { "@\(rawValue)" }

    init(validating input: String) throws(HandleError) {
        let value = Self.normalized(input)
        guard value.count >= Self.lengthRange.lowerBound else { throw .tooShort }
        guard value.count <= Self.lengthRange.upperBound else { throw .tooLong }
        guard value.unicodeScalars.allSatisfy(Self.isAllowed) else { throw .invalidCharacters }
        rawValue = value
    }

    /// A best-effort handle from a display name: "Pál Papp" becomes "pal_papp".
    static func suggestion(from displayName: String) -> String {
        let folded = displayName
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
        var result = ""
        for scalar in folded.unicodeScalars {
            if isAllowed(scalar) {
                result.unicodeScalars.append(scalar)
            } else if scalar.properties.isWhitespace || scalar == "-" || scalar == ".", !result.hasSuffix("_"), !result.isEmpty {
                result.append("_")
            }
        }
        while result.hasSuffix("_") { result.removeLast() }
        return String(result.prefix(lengthRange.upperBound))
    }

    private static func normalized(_ input: String) -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("@") { value.removeFirst() }
        return value
    }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "_"
    }
}

nonisolated enum HandleError: LocalizedError, Equatable {
    case tooShort
    case tooLong
    case invalidCharacters

    var errorDescription: String? {
        switch self {
        case .tooShort:
            String(localized: "At least 3 characters. Even birds have longer names.")
        case .tooLong:
            String(localized: "20 characters max. Nobody's typing all that.")
        case .invalidCharacters:
            String(localized: "Only a–z, 0–9 and underscores.")
        }
    }
}
