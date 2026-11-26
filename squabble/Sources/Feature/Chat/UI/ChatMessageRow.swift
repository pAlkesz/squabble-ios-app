import SwiftUI
import UIKit

/// One message in the chat: a bubble on the right for the user's own, on the left with the
/// author's avatar for everyone else's. Long press for reactions, reply, copy and delete or
/// report; a tap does nothing.
struct ChatMessageRow: View {
    let message: ChatMessage
    let author: GroupMember?
    let replyAuthorName: String?
    let isMine: Bool
    let startsRun: Bool
    let endsRun: Bool
    let showsName: Bool
    let myUID: String?
    let onReact: (String) -> Void
    let onShowReactions: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onShowQuoted: (String) -> Void

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
        // Room for the chips hanging below the bubble.
        .padding(.bottom, message.reactions.isEmpty ? 0 : Self.reactionOverhang + 2)
    }

    /// How far the reaction chips are pushed below the bubble: they overlap only its bottom
    /// padding, clear of the text and the time.
    private static let reactionOverhang: CGFloat = 18

    private var bubbleShape: ChatBubbleShape {
        ChatBubbleShape(tail: endsRun ? (isMine ? .trailing : .leading) : .none)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !isMine, showsName {
                Text(verbatim: authorName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            if let reply = message.replyTo, !message.isDeleted {
                quote(reply)
            }
            body(text: message.isDeleted
                ? Text("Message deleted", comment: "Chat: shown in place of a deleted message.").italic()
                : Text(verbatim: message.text))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.white.opacity(isMine ? 0.2 : 0.1), in: bubbleShape)
        .foregroundStyle(message.isDeleted ? .white.opacity(0.6) : .white)
        .contentShape(.contextMenuPreview, bubbleShape)
        .contextMenu { if !message.isDeleted { menu } }
        .accessibilityElement(children: .combine)
    }

    /// The time sits in the bubble's bottom corner: a clear copy at the end of the text keeps
    /// room for it, so short messages put it on the same line and long ones below.
    private func body(text: Text) -> some View {
        (text + Text(verbatim: "   " + timeText).font(.caption2).foregroundStyle(.clear))
            .font(.body)
            .overlay(alignment: .bottomTrailing) {
                timeLabel
            }
    }

    @ViewBuilder
    private var timeLabel: some View {
        if message.isPending {
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityLabel(Text("Not sent yet", comment: "Chat: VoiceOver label for a message still waiting for a connection."))
        } else {
            Text(verbatim: timeText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var timeText: String {
        (message.createdAt ?? .now).formatted(date: .omitted, time: .shortened)
    }

    private var authorName: String {
        Self.name(of: author)
    }

    static func name(of member: GroupMember?) -> String {
        guard let member, !member.isDeleted, !member.displayName.isEmpty else {
            return String(localized: "Deleted member", comment: "Chat and squabble pages: name shown for someone who deleted their account.")
        }
        return member.displayName
    }

    private func quote(_ reply: ChatReply) -> some View {
        Button {
            onShowQuoted(reply.messageID)
        } label: {
            HStack(spacing: 8) {
                Capsule()
                    .fill(.white.opacity(0.6))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: replyAuthorName ?? Self.name(of: nil))
                        .font(.caption.weight(.semibold))
                    Text(verbatim: reply.preview.isEmpty ? String(localized: "Message deleted", comment: "Chat: shown in place of a deleted message.") : reply.preview)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// Every reaction in one pill, as in Messenger: the most common few, then how many in all.
    /// Tapping it shows who reacted with what, where your own can be taken back.
    private var reactionPill: some View {
        let counts = message.reactionCounts
        let total = message.reactions.count
        let hasMine = myUID.map { message.reactions[$0] != nil } ?? false
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
                Capsule().strokeBorder(.white.opacity(hasMine ? 0.6 : 0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Reactions", comment: "Chat: VoiceOver label for the pill of reactions under a message, and the title of the sheet listing them."))
        .accessibilityValue(Text(verbatim: counts.map { "\($0.emoji) \($0.count)" }.joined(separator: ", ")))
    }

    private static let pillEmojiCount = 3

    @ViewBuilder
    private var menu: some View {
        ControlGroup {
            ForEach(ChatMessage.quickReactions, id: \.self) { emoji in
                Button {
                    onReact(emoji)
                } label: {
                    Text(verbatim: emoji)
                }
            }
        }
        .controlGroupStyle(.palette)
        Button(action: onReply) {
            Label {
                Text("Reply", comment: "Chat: long-press action that replies to a message.")
            } icon: {
                Image(systemName: "arrowshape.turn.up.left")
            }
        }
        Button {
            // SwiftUI has no pasteboard API of its own.
            UIPasteboard.general.string = message.text
        } label: {
            Label {
                Text("Copy", comment: "Chat: long-press action that copies a message's text.")
            } icon: {
                Image(systemName: "doc.on.doc")
            }
        }
        if isMine {
            Button(role: .destructive, action: onDelete) {
                Label {
                    Text("Delete", comment: "Chat: long-press action that deletes your own message.")
                } icon: {
                    Image(systemName: "trash")
                }
            }
        } else {
            Button(action: onReport) {
                Label {
                    Text("Report", comment: "Chat: long-press action that reports someone else's message.")
                } icon: {
                    Image(systemName: "exclamationmark.bubble")
                }
            }
        }
    }
}
