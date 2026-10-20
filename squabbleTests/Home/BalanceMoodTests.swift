import Foundation
import Testing
@testable import squabble

struct BalanceMoodTests {
    @Test func zeroIsNeutral() {
        #expect(BalanceMood(amount: 0, currencyCode: "EUR").intensity == 0)
    }

    @Test func signFollowsTheBalance() {
        #expect(BalanceMood(amount: 12, currencyCode: "EUR").intensity > 0)
        #expect(BalanceMood(amount: -12, currencyCode: "EUR").intensity < 0)
    }

    @Test func owingAndBeingOwedAreSymmetric() {
        let owed = BalanceMood(amount: 40, currencyCode: "EUR").intensity
        let owing = BalanceMood(amount: -40, currencyCode: "EUR").intensity
        #expect(owed == -owing)
    }

    @Test func biggerBalancesFeelStronger() {
        let amounts: [Decimal] = [0.01, 1, 5, 20, 50, 100, 249]
        let intensities = amounts.map { BalanceMood(amount: $0, currencyCode: "EUR").intensity }
        #expect(intensities == intensities.sorted())
        #expect(Set(intensities).count == intensities.count)
    }

    @Test func saturatesAtTheCap() {
        #expect(BalanceMood(amount: 250, currencyCode: "EUR").intensity == 1)
        #expect(BalanceMood(amount: 10_000, currencyCode: "EUR").intensity == 1)
        #expect(BalanceMood(amount: -10_000, currencyCode: "EUR").intensity == -1)
    }

    @Test func smallAmountsStayMild() {
        #expect(abs(BalanceMood(amount: 3, currencyCode: "EUR").intensity) < 0.35)
        #expect(BalanceMood(amount: 50, currencyCode: "EUR").intensity > 0.6)
    }

    @Test func judgesAmountsInRoughEuroTerms() {
        let euros = BalanceMood(amount: 20, currencyCode: "EUR").intensity
        let forints = BalanceMood(amount: 8_000, currencyCode: "HUF").intensity
        #expect(abs(euros - forints) < 1e-9)
        #expect(BalanceMood(amount: 500, currencyCode: "HUF").intensity < 0.35)
    }

    @Test func unknownCurrenciesCountLikeEuros() {
        let euros = BalanceMood(amount: 30, currencyCode: "EUR").intensity
        #expect(BalanceMood(amount: 30, currencyCode: "XYZ").intensity == euros)
    }
}
