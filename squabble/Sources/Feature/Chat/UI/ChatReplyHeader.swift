import SwiftUI

/// What a reply answers, above its bubble, as in Messenger: "↩ Anna replied to Béla", then the
/// quoted message as a faded bubble that the reply overlaps. Tapping the quote shows the
/// original if it's loaded.
struct ChatReplyHeader: View {
    let reply: ChatReply
    let authorID: String
    /// Names as the chat shows them.
    let authorName: String
    let quotedName: String
    let myUID: String?
    let isMine: Bool
    let onShowQuoted: (String) -> Void

    /// How far the reply's bubble covers the quote.
    static let overlap: CGFloat = 14

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            // Not a Label: its gap between icon and title is wider than this small line wants.
            HStack(spacing: 3) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text(verbatim: caption)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.65))
            .lineLimit(1)
            .padding(.horizontal, 12)
            Button {
                onShowQuoted(reply.messageID)
            } label: {
                Text(verbatim: preview)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 9)
                    .padding(.bottom, 9 + Self.overlap)
                    .background(.white.opacity(0.06), in: .rect(cornerRadius: SquabbleMetrics.bubbleCornerRadius))
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Shows the message it answers", comment: "Chat: VoiceOver hint on the quoted message above a reply."))
        }
        .padding(.bottom, -Self.overlap)
    }

    private var preview: String {
        reply.preview.isEmpty
            ? String(localized: "Message deleted", comment: "Chat: shown in place of a deleted message.")
            : reply.preview
    }

    private var caption: String {
        let quotedIsMe = reply.authorID == myUID
        switch (isMine, quotedIsMe, reply.authorID == authorID) {
        case (true, true, _):
            return String(localized: "You replied to yourself", comment: "Chat: above a reply the user wrote to their own message.")
        case (true, false, _):
            return String(localized: "You replied to \(quotedName)", comment: "Chat: above a reply the user wrote to someone; their name.")
        case (false, true, _):
            return String(localized: "\(authorName) replied to you", comment: "Chat: above someone's reply to the user's message; their name.")
        case (false, false, true):
            return String(localized: "\(authorName) replied to themselves", comment: "Chat: above someone's reply to their own message; their name.")
        case (false, false, false):
            return String(localized: "\(authorName) replied to \(quotedName)", comment: "Chat: above someone's reply to a third person; who replied, then to whom.")
        }
    }
}
