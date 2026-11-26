import SwiftUI

/// Any emoji as a reaction: every one in Unicode's groups, searchable by its English name.
/// Opened from the + at the end of the long-press menu's reaction bar.
struct EmojiPickerSheet: View {
    let selected: String?
    let onPick: (String) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private let catalog = EmojiCatalog.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                let groups = catalog.matching(query)
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(groups) { group in
                        Section {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 4) {
                                ForEach(group.emoji, id: \.self) { emoji in
                                    button(for: emoji)
                                }
                            }
                        } header: {
                            Text(verbatim: Self.title(of: group.id))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    }
                    if groups.isEmpty {
                        Text("No emoji by that name. Try another word.", comment: "Emoji picker: shown when a search finds nothing.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Search emoji", comment: "Emoji picker: placeholder of the search field.")
            )
            .navigationTitle(Text("Pick an emoji", comment: "Emoji picker: title of the sheet that offers every emoji as a reaction."))
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

    private func button(for emoji: EmojiCatalog.Emoji) -> some View {
        Button {
            onPick(emoji.character)
        } label: {
            Text(verbatim: emoji.character)
                .font(.system(size: 32))
                .frame(width: 44, height: 44)
                .background(.white.opacity(emoji.character == selected ? 0.2 : 0), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: emoji.name))
        .accessibilityAddTraits(emoji.character == selected ? .isSelected : [])
    }

    /// Unicode's group names, in the reader's language.
    static func title(of group: String) -> String {
        switch group {
        case "Smileys & Emotion": String(localized: "Smileys & emotion", comment: "Emoji picker: group heading.")
        case "People & Body": String(localized: "People & body", comment: "Emoji picker: group heading.")
        case "Animals & Nature": String(localized: "Animals & nature", comment: "Emoji picker: group heading.")
        case "Food & Drink": String(localized: "Food & drink", comment: "Emoji picker: group heading.")
        case "Travel & Places": String(localized: "Travel & places", comment: "Emoji picker: group heading.")
        case "Activities": String(localized: "Activities", comment: "Emoji picker: group heading.")
        case "Objects": String(localized: "Objects", comment: "Emoji picker: group heading.")
        case "Symbols": String(localized: "Symbols", comment: "Emoji picker: group heading.")
        case "Flags": String(localized: "Flags", comment: "Emoji picker: group heading.")
        default: group
        }
    }
}
