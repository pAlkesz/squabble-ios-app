import SwiftUI

/// A squabble in a list: its picture, its name, how many and in what currency, and when it
/// last saw activity. No chevron, as in Revolut's lists.
struct SquabbleRow: View {
    let group: SquabbleGroup
    var pictureSize: CGFloat = 56

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SquabbleImageView(group.image, size: pictureSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: group.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(minHeight: pictureSize)
            Spacer(minLength: 8)
            // Not there yet while the creation is still a pending write.
            if let updatedAt = group.updatedAt {
                Text(verbatim: ActivityDate.text(for: updatedAt))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 2)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }

    private var summary: String {
        String(
            localized: "\(group.currentMembers.count) members · \(group.currencyCode)",
            comment: "Squabble row: member count and the squabble's currency code."
        )
    }
}
