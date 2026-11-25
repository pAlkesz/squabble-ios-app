import SwiftUI

/// Opened from a bill in the chat: what it was, who owes what, and editing or deleting it,
/// which any member may do.
struct BillDetailView: View {
    let bill: Bill
    let group: SquabbleGroup
    let uid: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    shares
                    history
                }
                .padding(16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .foregroundStyle(.white)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) {
                if !group.isArchived { actions }
            }
        }
        .tint(.white)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(verbatim: bill.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(verbatim: bill.total.formatted())
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(
                "Paid by \(BillText.name(of: bill.paidBy, in: group)) · \(BillText.day(bill.date))",
                comment: "Bill details: who paid, then the day."
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private var shares: some View {
        VStack(spacing: 0) {
            ForEach(bill.shares.filter { $0.value != 0 }.keys.sorted(by: inMemberOrder), id: \.self) { person in
                HStack(spacing: 12) {
                    AvatarView(BillText.avatar(of: person, in: group), size: 36)
                    Text(verbatim: BillText.name(of: person, in: group))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(verbatim: bill.share(of: person).formatted())
                        .monospacedDigit()
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
            }
        }
        .padding(.vertical, 6)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
    }

    private func inMemberOrder(_ lhs: String, _ rhs: String) -> Bool {
        let left = group.memberIds.firstIndex(of: lhs) ?? .max, right = group.memberIds.firstIndex(of: rhs) ?? .max
        return left == right ? lhs < rhs : left < right
    }

    private var history: some View {
        VStack(spacing: 4) {
            Text(
                "Added by \(BillText.name(of: bill.createdBy, in: group)), \(Self.time(bill.createdAt))",
                comment: "Bill details: who added it, then the date and time."
            )
            if bill.isEdited {
                Text(
                    "Edited by \(BillText.name(of: bill.updatedBy, in: group)), \(Self.time(bill.updatedAt))",
                    comment: "Bill details: who last edited it, then the date and time."
                )
            }
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.6))
        .multilineTextAlignment(.center)
    }

    private static func time(_ date: Date?) -> String {
        (date ?? .now).formatted(date: .abbreviated, time: .shortened)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            SquabbleGlassButton(title: LocalizedStringResource("Delete", comment: "Chat: long-press action that deletes your own message."), systemImage: "trash") {
                isConfirmingDelete = true
            }
            .confirmationDialog(
                Text("Delete this bill?", comment: "Bill details: title of the delete confirmation."),
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    dismiss()
                    onDelete()
                } label: {
                    Text("Delete for everyone", comment: "Chat: confirms deleting a message.")
                }
            } message: {
                Text("Everyone's balance changes, and everyone will see it was you.", comment: "Bill details: explanation in the delete confirmation.")
            }
            SquabbleGlassButton(title: LocalizedStringResource("Edit", comment: "Bill details: button that opens the form."), systemImage: "pencil", kind: .prominent) {
                dismiss()
                onEdit()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: 560)
    }
}
