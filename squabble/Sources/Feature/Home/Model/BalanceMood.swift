import SwiftUI

/// How the user's total balance should feel: a signed intensity from −1 (deep in the red)
/// through 0 (all square) to 1 (owed a lot), and the backdrop that goes with it.
/// Hue says which way the money flows, saturation says how much: petrol at zero, amber
/// then red the more you owe, pale green then brand green the more you're owed.
nonisolated struct BalanceMood: Equatable, Sendable {
    let intensity: Double

    init(amount: Decimal, currencyCode: String) {
        // Only picks a colour, never touches money, so Double precision is plenty.
        let magnitude = abs(NSDecimalNumber(decimal: amount).doubleValue)
        let euros = magnitude / Self.unitsPerEuro(currencyCode)
        let scaled = min(1, log10(1 + euros) / log10(1 + Self.fullIntensityEuros))
        intensity = amount < 0 ? -scaled : scaled
    }

    // The colour assets' generated symbols are main-actor isolated.
    @MainActor var palette: BackdropPalette {
        let strength = abs(intensity)
        let isOwing = intensity < 0
        let (mild, strong) = isOwing ? (Self.amber, Self.red) : (Self.pale, BackdropPalette.brand)
        let mildAt = isOwing ? Self.owingMildIntensity : Self.owedMildIntensity
        if strength < mildAt {
            return Self.neutral.mixed(with: mild, by: strength / mildAt)
        }
        return mild.mixed(with: strong, by: (strength - mildAt) / (1 - mildAt))
    }

    /// Log scale, so €5, €50 and €250 each read as a real step rather than everything
    /// under €100 looking the same.
    private static let fullIntensityEuros = 250.0

    /// Where pale green sits fully: about €6.
    private static let owedMildIntensity = 0.35

    /// Where amber sits fully: about €1. Halfway between petrol and amber is a muddy
    /// khaki, so a debt has to get through it quickly to read as a warning.
    private static let owingMildIntensity = 0.125

    /// "Small" depends on the currency (5 HUF is nothing), so amounts are judged in rough
    /// euro terms. A vibe table, not exchange rates — swap for the real rates once home
    /// totals convert currencies.
    static func unitsPerEuro(_ currencyCode: String) -> Double {
        switch currencyCode.uppercased() {
        case "HUF": 400
        case "JPY": 160
        case "CZK": 25
        case "SEK", "NOK": 11
        case "DKK": 7.5
        case "RON": 5
        case "PLN": 4
        case "AUD": 1.6
        case "CAD": 1.5
        default: 1
        }
    }

    @MainActor private static let neutral = BackdropPalette(
        top: .balanceNeutralTop,
        high: .balanceNeutralHigh,
        mid: .balanceNeutralMid,
        deep: .balanceNeutralDeep
    )

    @MainActor private static let pale = BackdropPalette(
        top: .balancePaleTop,
        high: .balancePaleHigh,
        mid: .balancePaleMid,
        deep: .balancePaleDeep
    )

    @MainActor private static let amber = BackdropPalette(
        top: .balanceAmberTop,
        high: .balanceAmberHigh,
        mid: .balanceAmberMid,
        deep: .balanceAmberDeep
    )

    @MainActor private static let red = BackdropPalette(
        top: .balanceRedTop,
        high: .balanceRedHigh,
        mid: .balanceRedMid,
        deep: .balanceRedDeep
    )
}
