import SwiftUI

/// A bill in the chat: the user's side of it large, who paid what under it, and who shares it.
/// On the right when the user added it, like their messages. Tapping opens its details.
struct BillCard: View {
    let bill: Bill
    let group: SquabbleGroup
    let myUID: String?
    let onOpen: () -> Void

    private static let maxAvatars = 6

    var body: some View {
        if bill.isDeleted {
            deleted
        } else {
            HStack {
                if isMine { Spacer(minLength: 56) }
                Button(action: onOpen) { card }
                    .buttonStyle(.plain)
                if !isMine { Spacer(minLength: 56) }
            }
            .padding(.vertical, 6)
        }
    }

    private var isMine: Bool { bill.createdBy == myUID }

    private var side: BillSide { BillSide(bill: bill, uid: myUID) }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(verbatim: side.title(in: group))
            } icon: {
                Image(systemName: "arrow.trianglehead.branch")
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.12), in: .capsule)
            Text(verbatim: side.amount.formatted())
                .font(.system(.title, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(
                "\(BillText.name(of: bill.paidBy, in: group)) paid \(bill.total.formatted()) · \(bill.title)",
                comment: "Bill in the chat: who paid, the total, and what for."
            )
            .font(.subheadline)
            .multilineTextAlignment(.leading)
            HStack(alignment: .bottom) {
                avatars
                Spacer(minLength: 24)
                time
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.white.opacity(isMine ? 0.2 : 0.1), in: .rect(cornerRadius: SquabbleMetrics.bubbleCornerRadius))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var avatars: some View {
        let people = group.members.keys.filter { (bill.shares[$0] ?? 0) != 0 }.sorted()
        return HStack(spacing: -8) {
            ForEach(people.prefix(Self.maxAvatars), id: \.self) { uid in
                AvatarView(BillText.avatar(of: uid, in: group), size: 28)
            }
            if people.count > Self.maxAvatars {
                Text(verbatim: "+\(people.count - Self.maxAvatars)")
                    .font(.caption.weight(.semibold))
                    .padding(.leading, 14)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var time: some View {
        if bill.isPending {
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityLabel(Text("Not sent yet", comment: "Chat: VoiceOver label for a message still waiting for a connection."))
        } else {
            Text(verbatim: (bill.createdAt ?? .now).formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var deleted: some View {
        Text(
            "\(BillText.name(of: bill.updatedBy, in: group)) deleted “\(bill.title)”",
            comment: "Chat: line in place of a deleted bill; who deleted it, then its title."
        )
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.6))
        .multilineTextAlignment(.center)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}
