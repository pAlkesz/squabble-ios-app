import SwiftUI

/// Pushed from the bill form: who shares the bill, equally or by exact amounts.
struct BillSplitView: View {
    @Binding var draft: BillDraft
    let group: SquabbleGroup
    let me: String

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker(selection: Binding(get: { draft.split }, set: { split in withAnimation(.snappy) { draft.setSplit(split) } })) {
                    Text("Equally", comment: "Bill split: everyone ticked pays the same.").tag(Bill.Split.equally)
                    Text("By amounts", comment: "Bill form: the bill is split by amounts entered by hand.").tag(Bill.Split.exactly)
                } label: {
                    Text("Split", comment: "Bill form: row that opens how the bill is split, and that page's title.")
                }
                .pickerStyle(.segmented)
                VStack(spacing: 0) {
                    ForEach(draft.candidates, id: \.self) { uid in
                        row(uid)
                    }
                }
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
                Text(verbatim: footer)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(.white)
        .navigationTitle(Text("Split", comment: "Bill form: row that opens how the bill is split, and that page's title."))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(_ uid: String) -> some View {
        switch draft.split {
        case .equally:
            let isIn = draft.included.contains(uid)
            Button {
                draft.toggle(uid)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isIn ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isIn ? .white : .white.opacity(0.4))
                    person(uid)
                    if let share = draft.shares?[uid] {
                        Text(verbatim: Money(minorUnits: share, currencyCode: draft.currencyCode).formatted())
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .rowLayout()
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isIn ? .isSelected : [])
        case .exactly:
            HStack(spacing: 12) {
                person(uid)
                AmountField(text: draft.exactTexts[uid] ?? "", currencyCode: draft.currencyCode) { draft.setExact($0, for: uid) }
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 110)
                .accessibilityLabel(Text(verbatim: BillText.name(of: uid, in: group, me: me)))
                Text(verbatim: draft.currencyCode)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .rowLayout()
        }
    }

    private func person(_ uid: String) -> some View {
        HStack(spacing: 12) {
            AvatarView(BillText.avatar(of: uid, in: group), size: 36)
            Text(verbatim: BillText.name(of: uid, in: group, me: me))
                .lineLimit(1)
            Spacer(minLength: 8)
        }
    }

    private var footer: String {
        guard draft.total != nil else {
            return String(localized: "Enter the amount first", comment: "Bill split: shown before the bill has an amount.")
        }
        if let missing = draft.missing, missing.minorUnits != 0 { return Self.hint(missing: missing) }
        if draft.shares == nil {
            return String(localized: "Somebody has to pay. Pick at least one victim.", comment: "Bill split: nobody is ticked.")
        }
        return String(localized: "Every last cent is accounted for", comment: "Bill split: the shares add up to the total.")
    }

    static func hint(missing: Money) -> String {
        if missing.minorUnits > 0 {
            return String(localized: "\(missing.formatted()) still needs an owner", comment: "Bill split: how much of the total nobody has been given yet.")
        }
        let extra = Money(minorUnits: -missing.minorUnits, currencyCode: missing.currencyCode)
        return String(localized: "\(extra.formatted()) too much. Overcharging is a separate squabble.", comment: "Bill split: how far the amounts exceed the total.")
    }
}

private extension View {
    func rowLayout() -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: 54)
            .contentShape(.rect)
    }
}
