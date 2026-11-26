import SwiftUI

/// Who reacted to a message with what, opened from its reaction pill, as in Messenger. Your
/// own comes first and can be taken back from here; adding or changing one stays on the
/// long-press menu.
struct ChatReactionsSheet: View {
    let message: ChatMessage
    let group: SquabbleGroup
    let myUID: String?
    let onRemoveMine: () -> Void

    @Environment(\.dismiss) private var dismiss

    private static let avatarSize: CGFloat = 40

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(reactors, id: \.uid) { reactor in
                        row(reactor)
                    }
                }
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle(Text("Reactions", comment: "Chat: VoiceOver label for the pill of reactions under a message, and the title of the sheet listing them."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .foregroundStyle(.white)
        .presentationDetents([.medium, .large])
        .presentationBackground { ProfileBackdrop() }
    }

    /// Yours first, then by how common the emoji is (as in the pill), then by name.
    private var reactors: [(uid: String, emoji: String)] {
        let order = Dictionary(uniqueKeysWithValues: message.reactionCounts.enumerated().map { ($1.emoji, $0) })
        return message.reactions
            .map { (uid: $0.key, emoji: $0.value) }
            .sorted { lhs, rhs in
                if (lhs.uid == myUID) != (rhs.uid == myUID) { return lhs.uid == myUID }
                let left = order[lhs.emoji] ?? .max, right = order[rhs.emoji] ?? .max
                if left != right { return left < right }
                return name(of: lhs.uid).localizedStandardCompare(name(of: rhs.uid)) == .orderedAscending
            }
    }

    private func name(of uid: String) -> String {
        BillText.name(of: uid, in: group, me: myUID)
    }

    @ViewBuilder
    private func row(_ reactor: (uid: String, emoji: String)) -> some View {
        let isMine = reactor.uid == myUID
        let content = HStack(spacing: 14) {
            AvatarView(BillText.avatar(of: reactor.uid, in: group), size: Self.avatarSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name(of: reactor.uid))
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                if isMine {
                    Text("Tap to take it back", comment: "Reactions sheet: under the user's own reaction, which a tap removes.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 8)
            Text(verbatim: reactor.emoji)
                .font(.title2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(.rect)

        if isMine {
            Button {
                onRemoveMine()
                dismiss()
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}
