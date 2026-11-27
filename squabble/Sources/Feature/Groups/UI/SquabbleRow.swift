import SwiftUI

/// A squabble in a list, laid out like Revolut's: its picture, its name, the user's balance
/// there, the latest thing that happened in it, and when. A balance tints the row from the
/// left in its mood's colour. No chevron.
struct SquabbleRow: View {
    let group: SquabbleGroup
    var pictureSize: CGFloat = 56
    /// How strong the date and summary are; a lighter backdrop needs more.
    var secondaryOpacity = 0.6

    @Environment(RatesStore.self) private var rates
    @Environment(AuthSession.self) private var session

    /// A row that wasn't there fades and grows in where it lands; the others make room.
    static let arrival: AnyTransition = .opacity.combined(with: .scale(scale: 0.94, anchor: .top))
    /// Lists key it on their ids, so it plays when the order or the set of squabbles changes.
    static let reorder: Animation = .spring(duration: 0.45, bounce: 0.15)

    var body: some View {
        HStack(spacing: 14) {
            SquabbleImageView(group.image, size: pictureSize)
            // The date sits on the name's baseline in a column of its own, so no line runs
            // under it, as in Revolut's lists.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: group.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    // Above the message, which it would otherwise crowd out on one line.
                    balanceLine
                        .font(.subheadline)
                        .monospacedDigit()
                        .lineLimit(1)
                    Text(verbatim: SquabbleRowSummary.text(for: group, me: session.user?.id))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(secondaryOpacity))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Not there yet while the creation is still a pending write.
                if let updatedAt = group.updatedAt {
                    Text(verbatim: ActivityDate.text(for: updatedAt))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(secondaryOpacity))
                        .fixedSize()
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background { tint }
        .contentShape(.rect)
    }

    /// Nothing until the user pays or shares a bill: zero before that isn't settling anything.
    @ViewBuilder
    private var balanceLine: some View {
        if let balance, let uid = session.user?.id, let color = mood?.palette.top {
            let amount = Text(verbatim: Money(minorUnits: abs(balance.minorUnits), currencyCode: balance.currencyCode).formatted())
                .fontWeight(.semibold)
                .foregroundStyle(color)
            if balance.minorUnits < 0 {
                Text("You owe \(amount)", comment: "The user's balance in a squabble: what they owe altogether.")
            } else if balance.minorUnits > 0 {
                Text("You're owed \(amount)", comment: "The user's balance in a squabble: what they're owed altogether.")
            } else if group.isInvolved(uid) {
                Text("Settled up", comment: "Squabble row: the user's balance in the squabble is exactly zero.")
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
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
