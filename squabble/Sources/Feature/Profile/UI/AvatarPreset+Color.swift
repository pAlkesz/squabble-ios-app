import SwiftUI

extension AvatarPreset {
    var color: Color {
        switch self {
        case .meadow: .accentColor
        case .lagoon: .avatarLagoon
        case .coral: .avatarCoral
        case .mustard: .avatarMustard
        case .plum: .avatarPlum
        }
    }
}
