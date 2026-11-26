import SwiftUI

/// One message in the chat: a bubble on the right for the user's own, on the left with the
/// author's avatar for everyone else's. Long press opens `ChatMessageMenu` over it (reactions,
/// reply, copy, delete or report); a tap does nothing.
struct ChatMessageRow: View {
    let message: ChatMessage
    let author: GroupMember?
    let replyAuthorName: String?
    let isMine: Bool
    let startsRun: Bool
    let endsRun: Bool
    let showsName: Bool
    /// The long-press menu is showing this message.
    let isLifted: Bool
    let myUID: String?
    /// With the bubble's frame on screen, so the menu can open over it.
    let onOpenMenu: (CGRect) -> Void
    let onShowReactions: () -> Void
    let onShowQuoted: (String) -> Void

    /// The bubble's latest frame, kept out of SwiftUI state: it changes on every scroll, and
    /// only matters at the moment of a long press.
    @State private var bubbleFrame = FrameBox()

    private static let avatarSize: CGFloat = 32

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine {
                Spacer(minLength: 56)
            } else if endsRun {
                AvatarView(author?.avatar ?? .preset(.default(for: message.authorID)), size: Self.avatarSize)
            } else {
                Color.clear.frame(width: Self.avatarSize, height: 1)
            }
            bubble
                // On the bubble's bottom-right corner whoever wrote it, as in Messenger.
                .reactionPill(for: message, onTap: onShowReactions)
                // The menu shows an exact copy in its place while it's open.
                .opacity(isLifted ? 0 : 1)
            if !isMine {
                Spacer(minLength: 56)
            }
        }
        .padding(.top, startsRun ? 8 : 0)
    }

    private var bubble: some View {
        ChatBubble(
            message: message,
            authorName: !isMine && showsName ? Self.name(of: author) : nil,
            replyAuthorName: replyAuthorName,
            isMine: isMine,
            hasTail: endsRun,
            onShowQuoted: onShowQuoted
        )
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { bubbleFrame.rect = $0 }
        .onLongPressGesture(minimumDuration: 0.3) {
            guard !message.isDeleted else { return }
            onOpenMenu(bubbleFrame.rect)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("React or reply", comment: "Chat: VoiceOver action on a message that opens its menu of reactions and actions.")) {
            guard !message.isDeleted else { return }
            onOpenMenu(bubbleFrame.rect)
        }
    }

    static func name(of member: GroupMember?) -> String {
        guard let member, !member.isDeleted, !member.displayName.isEmpty else {
            return String(localized: "Deleted member", comment: "Chat and squabble pages: name shown for someone who deleted their account.")
        }
        return member.displayName
    }

    /// A plain reference, so writing to it never redraws anything.
    final class FrameBox {
        var rect: CGRect = .zero
    }
}
