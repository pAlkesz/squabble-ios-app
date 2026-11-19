import SwiftUI

/// A squabble on home's tile: its picture, its name, and how many and in what currency.
/// No chevron, as in Revolut's tiles; the trailing slot is kept for the user's balance in it.
struct SquabbleRow: View {
    let group: SquabbleGroup

    var body: some View {
        HStack(spacing: 14) {
            SquabbleImageView(group.image, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: group.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }

    private var summary: String {
        String(
            localized: "\(group.currentMembers.count) members · \(group.currencyCode)",
            comment: "Squabble row on home: member count and the squabble's currency code."
        )
    }
}
