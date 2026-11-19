import Foundation

/// One-tap names under the name field. Names don't have to be unique, so "Trip" five
/// times over is fine. The emoji only decorates the chip.
nonisolated enum SquabblePreset: CaseIterable, Sendable {
    case trip
    case flat
    case dinner
    case party
    case family
    case couple

    var name: String {
        switch self {
        case .trip: String(localized: "Trip", comment: "Squabble name preset: a holiday or trip.")
        case .flat: String(localized: "Flat", comment: "Squabble name preset: a shared flat or house.")
        case .dinner: String(localized: "Dinner", comment: "Squabble name preset: a meal out.")
        case .party: String(localized: "Party", comment: "Squabble name preset: a party.")
        case .family: String(localized: "Family", comment: "Squabble name preset: family expenses.")
        case .couple: String(localized: "Us two", comment: "Squabble name preset: a couple splitting things.")
        }
    }

    var emoji: String {
        switch self {
        case .trip: "🏝️"
        case .flat: "🛋️"
        case .dinner: "🍝"
        case .party: "🎉"
        case .family: "👨‍👩‍👧"
        case .couple: "💑"
        }
    }
}
