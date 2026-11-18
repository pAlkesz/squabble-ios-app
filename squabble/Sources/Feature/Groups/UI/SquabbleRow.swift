import SwiftUI

/// A squabble on home's list: its picture, its name, and how many and in what currency.
struct SquabbleRow: View {
    let group: SquabbleGroup

    var body: some View {
        HStack(spacing: 14) {
            SquabbleImageView(group.image, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: group.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(.rect)
    }

    private var summary: String {
        String(
            localized: "\(group.currentMembers.count) members · \(group.currencyCode)",
            comment: "Squabble row on home: member count and the squabble's currency code."
        )
    }
}
