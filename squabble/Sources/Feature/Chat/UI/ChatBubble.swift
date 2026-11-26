import SwiftUI

/// A message's bubble: the author's name when it starts their messages, the quoted reply, the
/// text with the time in its bottom corner, on a `ChatBubbleShape`. Shown in the timeline and,
/// lifted, in the long-press menu.
struct ChatBubble: View {
    let message: ChatMessage
    /// Shown above the text when set.
    let authorName: String?
    let replyAuthorName: String?
    let isMine: Bool
    let hasTail: Bool
    /// Tapping the quote; nil where the bubble is only shown, as in the menu.
    var onShowQuoted: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let authorName {
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
        .background(.white.opacity(isMine ? 0.2 : 0.1), in: shape)
        .foregroundStyle(message.isDeleted ? .white.opacity(0.6) : .white)
    }

    var shape: ChatBubbleShape {
        ChatBubbleShape(tail: hasTail ? (isMine ? .trailing : .leading) : .none)
    }

    /// The time sits in the bubble's bottom corner: a clear copy at the end of the text keeps
    /// room for it, so short messages put it on the same line and long ones below.
    private func body(text: Text) -> some View {
        (text + Text(verbatim: "   " + timeText).font(Self.timeFont).foregroundStyle(.clear))
            .font(.body)
            .overlay(alignment: .bottomTrailing) {
                timeLabel
            }
    }

    static let timeFont: Font = .caption

    @ViewBuilder
    private var timeLabel: some View {
        if message.isPending {
            Image(systemName: "clock")
                .font(Self.timeFont)
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityLabel(Text("Not sent yet", comment: "Chat: VoiceOver label for a message still waiting for a connection."))
        } else {
            Text(verbatim: timeText)
                .font(Self.timeFont)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var timeText: String {
        (message.createdAt ?? .now).formatted(date: .omitted, time: .shortened)
    }

    private func quote(_ reply: ChatReply) -> some View {
        Button {
            onShowQuoted?(reply.messageID)
        } label: {
            HStack(spacing: 8) {
                Capsule()
                    .fill(.white.opacity(0.6))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: replyAuthorName ?? ChatMessageRow.name(of: nil))
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
        .disabled(onShowQuoted == nil)
    }
}
