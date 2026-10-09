import Foundation

/// The disc behind a bird or persona avatar. Raw values are stored in Firestore.
nonisolated enum AvatarColor: String, CaseIterable, Sendable {
    case meadow
    case lagoon
    case coral
    case mustard
    case plum
    case tangerine
    case rose
    case indigo
    case olive
    case slate
    case cocoa

    /// The colour of the fallback bird when a stored avatar can't be read. Stable across
    /// launches and devices (unlike `hashValue`), so it never flickers between colours.
    static func `default`(for uid: String) -> AvatarColor {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in uid.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return allCases[Int(hash % UInt64(allCases.count))]
    }
}
