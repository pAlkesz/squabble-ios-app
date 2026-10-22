import Foundation

/// A currency the home total can be shown in, named in the reader's language.
nonisolated struct CurrencyOption: Identifiable, Equatable, Sendable {
    let code: String
    let name: String

    var id: String { code }

    /// Every common currency the locale can name, sorted by name.
    static func all(in locale: Locale = .current) -> [CurrencyOption] {
        Locale.commonISOCurrencyCodes
            .compactMap { code in
                locale.localizedString(forCurrencyCode: code).map { CurrencyOption(code: code, name: $0) }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Matches the code or any part of the name, ignoring case and accents.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return code.localizedStandardContains(query) || name.localizedStandardContains(query)
    }
}
