import SwiftUI

/// A section of home: a card with its title inside, top-left in a quiet colour, and its rows
/// below — the layout Revolut's home uses. With a destination, the title gets a chevron and
/// a "See all" closes the card, both pushing it.
struct HomeTile<Content: View>: View {
    let title: Text
    var destination: HomeRoute?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            content
            if let destination {
                NavigationLink(value: destination) {
                    Text("See all", comment: "Home: button at the bottom of a tile that opens the full list.")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
    }

    @ViewBuilder
    private var header: some View {
        let label = HStack(spacing: 4) {
            title
            if destination != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white.opacity(0.6))
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .accessibilityAddTraits(.isHeader)

        if let destination {
            NavigationLink(value: destination) { label.contentShape(.rect) }
                .buttonStyle(.plain)
        } else {
            label
        }
    }
}
