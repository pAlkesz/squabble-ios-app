import Foundation

/// A currency the home total can be shown in, named in the reader's language, with the
/// country it belongs to when there's one obvious country.
nonisolated struct CurrencyOption: Identifiable, Equatable, Sendable {
    let code: String
    let name: String
    /// The country shown with the currency ("European Union" for the euro); `nil` for
    /// currencies shared by several countries.
    let countryName: String?
    let flagRegion: String?

    var id: String { code }

    /// The flag as an emoji: two regional indicator symbols spelling the region code.
    var flag: String? {
        guard let flagRegion else { return nil }
        let scalars = flagRegion.unicodeScalars.compactMap { Unicode.Scalar(0x1F1A5 + $0.value) }
        return String(String.UnicodeScalarView(scalars))
    }

    init(code: String, locale: Locale = .current) {
        self.code = code
        name = locale.localizedString(forCurrencyCode: code) ?? code
        flagRegion = Self.region(for: code)
        countryName = flagRegion.flatMap { locale.localizedString(forRegionCode: $0) }
    }

    /// Every common currency the locale can name, sorted by name.
    static func all(in locale: Locale = .current) -> [CurrencyOption] {
        Locale.commonISOCurrencyCodes
            .filter { locale.localizedString(forCurrencyCode: $0) != nil }
            .map { CurrencyOption(code: $0, locale: locale) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Matches the code, the name or the country, ignoring case and accents.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return [code, name, countryName ?? ""].contains { $0.localizedStandardContains(query) }
    }

    /// ISO 4217 codes start with the issuing country's code (HUF, GBP, and EUR with the
    /// EU, which Foundation lists as a region), which settles currencies used in several
    /// places, like USD. Otherwise only a currency used in exactly
    /// one region gets a country.
    private static func region(for code: String) -> String? {
        let users = regionsByCurrency[code] ?? []
        let prefix = String(code.prefix(2))
        if users.contains(prefix) { return prefix }
        return users.count == 1 ? users.first : nil
    }

    private static let regionsByCurrency: [String: [String]] = {
        var map: [String: [String]] = [:]
        for region in Locale.Region.isoRegions {
            let id = region.identifier
            // Numeric codes are continents and other groupings, which have no currency.
            guard id.count == 2, id.allSatisfy(\.isLetter),
                  let currency = Locale(identifier: "en_\(id)").currency?.identifier
            else { continue }
            map[currency, default: []].append(id)
        }
        return map
    }()
}
