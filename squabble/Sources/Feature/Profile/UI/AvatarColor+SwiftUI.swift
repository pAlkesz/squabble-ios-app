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
}
