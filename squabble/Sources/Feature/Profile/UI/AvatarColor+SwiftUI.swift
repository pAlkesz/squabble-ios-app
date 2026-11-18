import SwiftUI

extension AvatarColor {
    var color: Color {
        switch self {
        case .meadow: Color(.accent)
        case .lagoon: .avatarLagoon
        case .coral: .avatarCoral
        case .mustard: .avatarMustard
        case .plum: .avatarPlum
        case .tangerine: .avatarTangerine
        case .rose: .avatarRose
        case .indigo: .avatarIndigo
        case .olive: .avatarOlive
        case .slate: .avatarSlate
        case .cocoa: .avatarCocoa
        }
    }

    /// For VoiceOver on colour pickers.
    var name: String {
        switch self {
        case .meadow: String(localized: "Green", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .lagoon: String(localized: "Blue", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .coral: String(localized: "Coral", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .mustard: String(localized: "Mustard", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .plum: String(localized: "Plum", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .tangerine: String(localized: "Orange", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .rose: String(localized: "Pink", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .indigo: String(localized: "Indigo", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .olive: String(localized: "Olive", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .slate: String(localized: "Slate", comment: "Colour name, read by VoiceOver in colour pickers.")
        case .cocoa: String(localized: "Brown", comment: "Colour name, read by VoiceOver in colour pickers.")
        }
    }
}
