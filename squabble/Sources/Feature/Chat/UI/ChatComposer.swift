import SwiftUI

/// The bottom of a squabble's chat: Add a bill on the left (the app's main action, kept in
/// thumb reach), the message field, and send once there's something to send. A reply being
/// written shows above it.
struct ChatComposer: View {
    @Binding var text: String
    let replyingTo: ChatMessage?
    let replyAuthorName: String?
    var isFocused: FocusState<Bool>.Binding
    let onCancelReply: () -> Void
    let onSend: () -> Void
    let onAddBill: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let replyingTo {
                replyBanner(replyingTo)
            }
            HStack(alignment: .bottom, spacing: 10) {
                Button(action: onAddBill) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(Text("Add a bill", comment: "Squabble page: button at the bottom that adds a bill."))

                HStack(alignment: .bottom, spacing: 8) {
                    TextField(
                        "Message",
                        text: $text,
                        prompt: Text("Type a message…", comment: "Chat: placeholder in the message field.")
                            .foregroundStyle(.white.opacity(0.55)),
                        axis: .vertical
                    )
                    .lineLimit(1...5)
                    .focused(isFocused)
                    .padding(.vertical, 11)
                    if canSend {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.bold))
                                .foregroundStyle(Color.backdropDeep)
                                .frame(width: 32, height: 32)
                                .background(.white, in: .circle)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 6)
                        .accessibilityLabel(Text("Send", comment: "Chat: VoiceOver label for the send button."))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, canSend ? 6 : 16)
                .frame(minHeight: 44)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
            }
            .animation(.snappy(duration: 0.2), value: canSend)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func replyBanner(_ message: ChatMessage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 1) {
                Text("Replying to \(replyAuthorName ?? "")", comment: "Chat: above the message field while writing a reply; the argument is the author's name.")
                    .font(.caption.weight(.semibold))
                Text(verbatim: message.text)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
            Button(action: onCancelReply) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Cancel reply", comment: "Chat: VoiceOver label for the button that stops replying."))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: SquabbleMetrics.bubbleCornerRadius))
    }
}
