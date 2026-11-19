import Foundation

/// The gradient behind a squabble's drawing. Deliberately its own palette, apart from
/// `AvatarColor`, so a squabble never looks like a person. Raw values are stored: never
/// rename one.
nonisolated enum SquabbleBackground: String, CaseIterable, Sendable {
    case mint
    case sky
    case peach
    case lilac
    case sunrise
    case bubblegum
    case teal
    case dusk
    case sand
    case storm

    /// Stable for a given squabble, like a person's fallback colour.
    static func `default`(for groupID: String) -> SquabbleBackground {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in groupID.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return allCases[Int(hash % UInt64(allCases.count))]
    }
}
