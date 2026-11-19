import SwiftUI

extension SquabbleBackground {
    /// Light at the top left, deepening towards the bottom, where the drawing's figures sit.
    var gradient: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: UnitPoint(x: 0.65, y: 1))
    }

    private var top: Color {
        switch self {
        case .mint: .squabbleMintTop
        case .sky: .squabbleSkyTop
        case .peach: .squabblePeachTop
        case .lilac: .squabbleLilacTop
        case .sunrise: .squabbleSunriseTop
        case .bubblegum: .squabbleBubblegumTop
        case .teal: .squabbleTealTop
        case .dusk: .squabbleDuskTop
        case .sand: .squabbleSandTop
        case .storm: .squabbleStormTop
        }
    }

    private var bottom: Color {
        switch self {
        case .mint: .squabbleMintBottom
        case .sky: .squabbleSkyBottom
        case .peach: .squabblePeachBottom
        case .lilac: .squabbleLilacBottom
        case .sunrise: .squabbleSunriseBottom
        case .bubblegum: .squabbleBubblegumBottom
        case .teal: .squabbleTealBottom
        case .dusk: .squabbleDuskBottom
        case .sand: .squabbleSandBottom
        case .storm: .squabbleStormBottom
        }
    }

    /// For VoiceOver on the background picker.
    var name: String {
        switch self {
        case .mint: String(localized: "Mint", comment: "Squabble background name, read by VoiceOver.")
        case .sky: String(localized: "Sky", comment: "Squabble background name, read by VoiceOver.")
        case .peach: String(localized: "Peach", comment: "Squabble background name, read by VoiceOver.")
        case .lilac: String(localized: "Lilac", comment: "Squabble background name, read by VoiceOver.")
        case .sunrise: String(localized: "Sunrise", comment: "Squabble background name, read by VoiceOver.")
        case .bubblegum: String(localized: "Bubblegum", comment: "Squabble background name, read by VoiceOver.")
        case .teal: String(localized: "Teal", comment: "Squabble background name, read by VoiceOver.")
        case .dusk: String(localized: "Dusk", comment: "Squabble background name, read by VoiceOver.")
        case .sand: String(localized: "Sand", comment: "Squabble background name, read by VoiceOver.")
        case .storm: String(localized: "Storm", comment: "Squabble background name, read by VoiceOver.")
        }
    }
}
