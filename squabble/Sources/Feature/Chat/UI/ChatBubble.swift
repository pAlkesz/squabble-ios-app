import SwiftUI

/// A message's bubble: the author's name when it starts their messages, the text with the time
/// in its bottom corner, on a `ChatBubbleShape`. A reply's quote sits above it
/// (`ChatReplyHeader`), not inside. Shown in the timeline and, lifted, in the long-press menu.
struct ChatBubble: View {
    let message: ChatMessage
    /// Shown above the text when set.
    let authorName: String?
    let isMine: Bool
    let hasTail: Bool
    /// Cuts away what's under it in the enclosing compositing group (a reply's quote), so the
    /// see-through fill comes out the same colour as every other bubble. Only inside such a group:
    /// elsewhere it would cut a hole through to whatever is behind.
    var erasesBehind = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let authorName {
                Text(verbatim: authorName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            body(text: message.isDeleted
                ? Text("Message deleted", comment: "Chat: shown in place of a deleted message.").italic()
                : Text(verbatim: message.text))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.white.opacity(isMine ? 0.2 : 0.1), in: shape)
        .background {
            if erasesBehind {
                shape.fill(.black).blendMode(.destinationOut)
            }
        }
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
}
