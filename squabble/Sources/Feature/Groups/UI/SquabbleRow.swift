import SwiftUI

/// A squabble in a list: its picture, its name, the latest thing that happened in it, when,
/// and the user's balance there. A balance tints the row from the left in its mood's colour.
/// No chevron, as in Revolut's lists.
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
                    Text(verbatim: SquabbleRowSummary.text(for: group, me: session.user?.id))
                        .foregroundStyle(.white.opacity(secondaryOpacity))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    balanceText
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .font(.subheadline)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background { tint }
        .contentShape(.rect)
    }

    /// Nothing before the first bill: there's no balance to speak of yet.
    @ViewBuilder
    private var balanceText: some View {
        if group.balances != nil, let balance {
            if balance.minorUnits == 0 {
                Text("Settled up", comment: "Squabble row: the user's balance in the squabble is exactly zero.")
                    .foregroundStyle(mood?.palette.top ?? .white)
            } else {
                Text(verbatim: balance.formattedWithSign())
                    .foregroundStyle(mood?.palette.top ?? .white)
                    .accessibilityLabel(Text(verbatim: BillText.standing(balance)))
            }
        }
    }

    /// Inset a little from the card, so neighbouring tinted rows read as separate.
    @ViewBuilder
    private var tint: some View {
        if let balance, balance.minorUnits != 0, let mood {
            LinearGradient(
                stops: [
                    .init(color: mood.palette.high.opacity(0.55), location: 0),
                    .init(color: mood.palette.high.opacity(0.18), location: 0.55),
                    .init(color: mood.palette.high.opacity(0), location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(.rect(cornerRadius: SquabbleMetrics.cornerRadius))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
    }

    private var balance: Money? {
        session.user.map { group.balance(of: $0.id) }
    }

    private var mood: BalanceMood? {
        balance.map { BalanceMood(balances: [$0], rates: rates.rates) }
    }
}
