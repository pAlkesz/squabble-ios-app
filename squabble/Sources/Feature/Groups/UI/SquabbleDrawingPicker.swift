import SwiftUI

/// Pushed from the create-squabble sheet: a drawing and a background for squabbles without
/// a photo. Changes apply as they're tapped; back keeps them.
struct SquabbleDrawingPicker: View {
    let artwork: SquabbleArtwork
    @Binding var background: SquabbleBackground
    let onPickArtwork: (SquabbleArtwork) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                SquabbleImageView(.artwork(artwork, background), size: 120)
                    .animation(.snappy, value: artwork)
                    .animation(.snappy, value: background)
                section(Text("Backgrounds", comment: "Squabble drawing picker: header above the backgrounds.")) {
                    LazyVGrid(columns: Self.columns, spacing: 14) {
                        ForEach(SquabbleBackground.allCases, id: \.self) { option in
                            Button {
                                background = option
                            } label: {
                                Circle()
                                    .fill(option.gradient)
                                    .frame(width: 52, height: 52)
                                    .padding(4)
                                    .overlay {
                                        Circle().strokeBorder(.white, lineWidth: option == background ? 3 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: option.name))
                            .accessibilityAddTraits(option == background ? .isSelected : [])
                        }
                    }
                }
                section(Text("Drawings", comment: "Squabble drawing picker: header above the drawings.")) {
                    LazyVGrid(columns: Self.columns, spacing: 14) {
                        ForEach(SquabbleArtwork.allCases, id: \.self) { option in
                            Button {
                                onPickArtwork(option)
                            } label: {
                                SquabbleImageView(.artwork(option, background), size: 52)
                                    .padding(4)
                                    .overlay {
                                        Circle().strokeBorder(.white, lineWidth: option == artwork ? 3 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: option.name))
                            .accessibilityAddTraits(option == artwork ? .isSelected : [])
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
        .navigationTitle(Text("Drawing", comment: "Squabble drawing picker: page title."))
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let columns = [GridItem(.adaptive(minimum: 60), spacing: 14)]

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
