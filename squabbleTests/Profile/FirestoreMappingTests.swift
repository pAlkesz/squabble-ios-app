import Foundation
import Testing
@testable import squabble

struct FirestoreMappingTests {
    @Test(arguments: [
        Avatar.preset(.mustard),
        .persona(.bigSpender, .plum),
        .photo(path: "avatars/uid-1/a.jpg", url: URL(string: "https://example.com/a.jpg")!),
    ])
    func profileRoundTrips(avatar: Avatar) throws {
        let profile = UserProfile(id: "uid-1", displayName: "Pál", handle: try Handle(validating: "pal"), avatar: avatar)
        #expect(try UserProfile(id: "uid-1", firestoreData: profile.firestoreData) == profile)
    }

    @Test func unreadableAvatarFallsBackToTheDefaultBird() throws {
        let data: [String: Any] = ["displayName": "Pál", "handle": "pal", "avatar": ["kind": "hologram"]]
        let profile = try UserProfile(id: "uid-1", firestoreData: data)
        #expect(profile.avatar == .preset(.default(for: "uid-1")))
    }

    @Test func personaThisAppDoesntKnowFallsBackToTheDefaultBird() throws {
        let data: [String: Any] = ["displayName": "Pál", "handle": "pal", "avatar": ["kind": "persona", "persona": "fromTheFuture", "color": "plum"]]
        let profile = try UserProfile(id: "uid-1", firestoreData: data)
        #expect(profile.avatar == .preset(.default(for: "uid-1")))
    }

    @Test func missingFieldsAreMalformed() {
        #expect(throws: FirestoreMappingError.malformed("users/uid-1")) {
            try UserProfile(id: "uid-1", firestoreData: ["displayName": "Pál"])
        }
    }

    @Test func paymentMethodsRoundTrip() throws {
        let methods = [
            PaymentMethod(kind: .bankAccount(iban: try IBAN(validating: "DE89370400440532013000"), holderName: "Pál Papp")),
            PaymentMethod(kind: .link(try PaymentLink(provider: .revolut, input: "pal"))),
        ]
        #expect(methods.compactMap { PaymentMethod(firestoreData: $0.firestoreData) } == methods)
    }

    @Test func corruptPaymentMethodIsSkipped() {
        let data: [String: Any] = ["id": "x", "kind": "bankAccount", "iban": "DE00", "holderName": "Pál"]
        #expect(PaymentMethod(firestoreData: data) == nil)
    }
}

struct UserPreferencesMappingTests {
    @Test func homeCurrencyRoundTrips() {
        let preferences = UserPreferences(homeCurrencyCode: "HUF")
        #expect(UserPreferences(firestoreData: preferences.firestoreData) == preferences)
    }

    @Test func automaticIsStoredAsNoField() {
        #expect(UserPreferences().firestoreData.isEmpty)
        #expect(UserPreferences(firestoreData: [:]).homeCurrencyCode == nil)
    }

    @Test(arguments: ["huf", "EURO", "", "€"])
    func malformedCodesFallBackToAutomatic(_ code: String) {
        #expect(UserPreferences(firestoreData: ["homeCurrency": code]).homeCurrencyCode == nil)
    }

    @Test func resolvesToTheChosenCurrencyOverTheDevice() {
        #expect(UserPreferences(homeCurrencyCode: "JPY").resolvedHomeCurrencyCode == "JPY")
        #expect(UserPreferences().resolvedHomeCurrencyCode == UserPreferences.deviceCurrencyCode)
    }
}

struct MemberSinceMappingTests {
    @Test func readsTheCreatedDate() throws {
        let created = Date(timeIntervalSince1970: 1_790_000_000)
        let data: [String: Any] = ["displayName": "Pál", "handle": "pal", "createdAt": created]
        #expect(try UserProfile(id: "uid-1", firestoreData: data).memberSince == created)
    }

    @Test func pendingServerTimestampIsUnknown() throws {
        let data: [String: Any] = ["displayName": "Pál", "handle": "pal", "createdAt": NSNull()]
        #expect(try UserProfile(id: "uid-1", firestoreData: data).memberSince == nil)
    }
}
