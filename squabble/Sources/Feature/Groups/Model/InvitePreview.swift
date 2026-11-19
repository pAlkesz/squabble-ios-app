import Foundation

/// What someone sees before joining by link: the server's answer, since a non-member can't
/// read the squabble itself.
nonisolated struct InvitePreview: Equatable, Sendable {
    let groupID: String
    let name: String
    let image: SquabbleImage
    let memberCount: Int
    let isMember: Bool
    let isArchived: Bool

    var isFull: Bool { memberCount >= SquabbleGroup.maxMembers }
}
