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
    let myUID: String?
    let onReact: (String) -> Void
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
                    // Clear of the reaction chips, level with the bubble's bottom.
                    .padding(.bottom, message.reactions.isEmpty ? 0 : 30)
            } else {
                Color.clear.frame(width: Self.avatarSize, height: 1)
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                bubble
                if !message.reactions.isEmpty {
                    reactionChips
                }
            }
            if !isMine {
                Spacer(minLength: 56)
            }
        }
        .padding(.top, startsRun ? 8 : 0)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !isMine, startsRun {
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
        .background(.white.opacity(isMine ? 0.2 : 0.1), in: .rect(cornerRadius: SquabbleMetrics.bubbleCornerRadius))
        .foregroundStyle(message.isDeleted ? .white.opacity(0.6) : .white)
        .contentShape(.contextMenuPreview, .rect(cornerRadius: SquabbleMetrics.bubbleCornerRadius))
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

    private var reactionChips: some View {
        HStack(spacing: 4) {
            ForEach(message.reactionCounts, id: \.emoji) { reaction in
                let isMineReaction = myUID.map { message.reactions[$0] == reaction.emoji } ?? false
                Button {
                    onReact(reaction.emoji)
                } label: {
                    Text(verbatim: reaction.count > 1 ? "\(reaction.emoji) \(reaction.count)" : reaction.emoji)
                        .font(.footnote)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(isMineReaction ? 0.28 : 0.12), in: .capsule)
                        .overlay {
                            if isMineReaction { Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1) }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isMineReaction ? .isSelected : [])
            }
        }
    }

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
