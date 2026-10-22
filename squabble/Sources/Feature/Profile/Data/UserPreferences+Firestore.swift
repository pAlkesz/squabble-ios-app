import Foundation

nonisolated extension UserPreferences {
    enum Field {
        static let homeCurrency = "homeCurrency"
    }

    init(firestoreData data: [String: Any]) {
        let code = data[Field.homeCurrency] as? String
        self.init(homeCurrencyCode: code.flatMap(Self.validCurrencyCode))
    }

    var firestoreData: [String: Any] {
        homeCurrencyCode.map { [Field.homeCurrency: $0] } ?? [:]
    }

    /// The same shape `firestore.rules` enforces.
    static func validCurrencyCode(_ code: String) -> String? {
        code.count == 3 && code.allSatisfy { $0.isASCII && $0.isUppercase } ? code : nil
    }
}
