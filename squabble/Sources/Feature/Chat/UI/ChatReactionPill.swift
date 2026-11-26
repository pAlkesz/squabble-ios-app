import SwiftUI

/// Every reaction on a message in one pill, as in Messenger: the most common few, then how many
/// in all. It sits on the bubble's bottom-right corner, overlapping only its bottom padding.
struct ChatReactionPill: View {
    let message: ChatMessage
    /// Tapping shows who reacted; nil where the pill is only shown, as in the menu.
    var onTap: (() -> Void)?

    /// How far the pill is pushed below the bubble: clear of the text and the time.
    static let overhang: CGFloat = 18

    private static let emojiCount = 3

    var body: some View {
        let counts = message.reactionCounts
        let total = message.reactions.count
        Button {
            onTap?()
        } label: {
            HStack(spacing: 2) {
                ForEach(counts.prefix(Self.emojiCount), id: \.emoji) { reaction in
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
        // Not disabled where there's nothing to do: a disabled button greys out.
        .allowsHitTesting(onTap != nil)
        .accessibilityLabel(Text("Reactions", comment: "Chat: VoiceOver label for the pill of reactions under a message, and the title of the sheet listing them."))
        .accessibilityValue(Text(verbatim: counts.map { "\($0.emoji) \($0.count)" }.joined(separator: ", ")))
    }
}

extension View {
    /// Hangs the message's reaction pill off this bubble's bottom-right corner, and makes room
    /// for it below.
    func reactionPill(for message: ChatMessage, onTap: (() -> Void)? = nil) -> some View {
        overlay(alignment: .bottomTrailing) {
            if !message.reactions.isEmpty {
                ChatReactionPill(message: message, onTap: onTap)
                    .offset(x: -10, y: ChatReactionPill.overhang)
            }
        }
        .padding(.bottom, message.reactions.isEmpty ? 0 : ChatReactionPill.overhang + 2)
    }
}
