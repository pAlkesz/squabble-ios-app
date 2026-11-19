import SwiftUI

extension SquabbleArtwork {
    /// Transparent art framed to fill the disc, with the figures running off its bottom.
    var image: Image {
        switch self {
        case .trio: Image(.artTrio)
        case .suits: Image(.artSuits)
        }
    }

    /// For VoiceOver on the drawing picker.
    var name: String {
        switch self {
        case .trio: String(localized: "The trio", comment: "Name of a squabble drawing (three friends), read by VoiceOver.")
        case .suits: String(localized: "The suits", comment: "Name of a squabble drawing (three men in business suits), read by VoiceOver.")
        }
    }
}
