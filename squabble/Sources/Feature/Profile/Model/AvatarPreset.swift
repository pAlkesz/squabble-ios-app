import Foundation

/// The bird on a coloured disc — every profile's default, and the fallback when a
/// photo won't load.
nonisolated enum AvatarPreset: String, CaseIterable, Sendable {
    case meadow
    case lagoon
    case coral
    case mustard
    case plum

    var accessibilityName: String {
        switch self {
        case .meadow: String(localized: "Green bird")
        case .lagoon: String(localized: "Blue bird")
        case .coral: String(localized: "Coral bird")
        case .mustard: String(localized: "Yellow bird")
        case .plum: String(localized: "Purple bird")
        }
    }

    /// Stable across launches and devices (unlike `hashValue`), so a user who never picks
    /// a colour always gets the same one.
    static func `default`(for uid: String) -> AvatarPreset {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in uid.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return allCases[Int(hash % UInt64(allCases.count))]
    }
}
