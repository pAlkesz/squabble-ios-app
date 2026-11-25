import SwiftUI

/// A squabble in a list: its picture, its name, how many and in what currency, and when it
/// last saw activity. No chevron, as in Revolut's lists.
struct SquabbleRow: View {
    let group: SquabbleGroup
    var pictureSize: CGFloat = 56
    /// How strong the date and summary are; a lighter backdrop needs more.
    var secondaryOpacity = 0.6

    @Environment(RatesStore.self) private var rates
    @Environment(AuthSession.self) private var session

    var body: some View {
        HStack(spacing: 14) {
            SquabbleImageView(group.image, size: pictureSize)
                .overlay {
                    if let balance, balance.minorUnits != 0 {
                        Circle()
                            .strokeBorder(BalanceMood(balances: [balance], rates: rates.rates).palette.top, lineWidth: 3)
                            .padding(-5)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                // The date sits on the name's baseline, as in Revolut's lists.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: group.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    // Not there yet while the creation is still a pending write.
                    if let updatedAt = group.updatedAt {
                        Text(verbatim: ActivityDate.text(for: updatedAt))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(secondaryOpacity))
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(summary)
                        .foregroundStyle(.white.opacity(secondaryOpacity))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let balance, balance.minorUnits != 0 {
                        Text(verbatim: balance.formattedWithSign())
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .lineLimit(1)
                            .layoutPriority(1)
                            .accessibilityLabel(Text(verbatim: BillText.standing(balance)))
                    }
                }
                .font(.subheadline)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }

    private var balance: Money? {
        session.user.map { group.balance(of: $0.id) }
    }

    private var summary: String {
        String(
            localized: "\(group.currentMembers.count) members · \(group.currencyCode)",
            comment: "Squabble row: member count and the squabble's currency code."
        )
    }
}
