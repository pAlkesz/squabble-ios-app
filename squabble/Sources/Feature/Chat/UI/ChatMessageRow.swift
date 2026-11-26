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
                .overlay(alignment: .bottomTrailing) {
                    if !message.reactions.isEmpty {
                        reactionPill
                            .offset(x: -10, y: Self.reactionOverhang)
                    }
                }
            if !isMine {
                Spacer(minLength: 56)
            }
        }
        .padding(.top, startsRun ? 8 : 0)
        // Room for the pill hanging below the bubble.
        .padding(.bottom, message.reactions.isEmpty ? 0 : Self.reactionOverhang + 2)
    }

    /// How far the reaction pill is pushed below the bubble: it overlaps only its bottom
    /// padding, clear of the text and the time.
    private static let reactionOverhang: CGFloat = 18

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

    /// Every reaction in one pill, as in Messenger: the most common few, then how many in all.
    /// Tapping it shows who reacted with what, where your own can be taken back.
    private var reactionPill: some View {
        let counts = message.reactionCounts
        let total = message.reactions.count
        return Button(action: onShowReactions) {
            HStack(spacing: 2) {
                ForEach(counts.prefix(Self.pillEmojiCount), id: \.emoji) { reaction in
                    Text(verbatim: reaction.emoji)
                }
                if total > 1 {
                    Text(total, format: .number)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.leading, 2)
                }
            }
            .font(.footnote)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            // Opaque and dark, so it reads over the bubble it overlaps.
            .background(Color.reactionChip, in: .capsule)
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Reactions", comment: "Chat: VoiceOver label for the pill of reactions under a message, and the title of the sheet listing them."))
        .accessibilityValue(Text(verbatim: counts.map { "\($0.emoji) \($0.count)" }.joined(separator: ", ")))
    }

    private static let pillEmojiCount = 3

    /// A plain reference, so writing to it never redraws anything.
    final class FrameBox {
        var rect: CGRect = .zero
    }
}
