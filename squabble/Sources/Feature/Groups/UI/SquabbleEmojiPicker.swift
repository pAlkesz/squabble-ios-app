import SwiftUI

/// Pushed from the create-squabble sheet: an emoji and a colour for squabbles without a
/// photo. Changes apply as they're tapped; back keeps them.
struct SquabbleEmojiPicker: View {
    let emoji: String
    @Binding var color: AvatarColor
    let onPickEmoji: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                SquabbleImageView(.emoji(emoji, color), size: 120)
                    .animation(.snappy, value: emoji)
                    .animation(.snappy, value: color)
                section(Text("Colour", comment: "Squabble emoji picker: header above the colours.")) {
                    LazyVGrid(columns: Self.columns, spacing: 14) {
                        ForEach(AvatarColor.allCases, id: \.self) { option in
                            Button {
                                color = option
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 44, height: 44)
                                    .padding(4)
                                    .overlay {
                                        Circle().strokeBorder(.white, lineWidth: option == color ? 3 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: option.name))
                            .accessibilityAddTraits(option == color ? .isSelected : [])
                        }
                    }
                }
                section(Text("Emoji", comment: "Squabble emoji picker: header above the emojis.")) {
                    LazyVGrid(columns: Self.columns, spacing: 14) {
                        ForEach(SquabbleImage.emojis, id: \.self) { option in
                            Button {
                                onPickEmoji(option)
                            } label: {
                                Text(verbatim: option)
                                    .font(.system(size: 30))
                                    .frame(width: 52, height: 52)
                                    .background(.white.opacity(option == emoji ? 0.22 : 0.08), in: .circle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(option == emoji ? .isSelected : [])
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .foregroundStyle(.white)
        .navigationTitle(Text("Emoji"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let columns = [GridItem(.adaptive(minimum: 52), spacing: 14)]

    private func section(_ title: Text, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))
            content()
        }
    }
}
