import SwiftUI

/// A section of home: a card with its title inside, top-left in a quiet colour, and its rows
/// below — the layout Revolut's home uses. Squabbles is the first; expenses and the like
/// will follow in the same shape.
struct HomeTile<Content: View>: View {
    let title: Text
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            content
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
    }
}
