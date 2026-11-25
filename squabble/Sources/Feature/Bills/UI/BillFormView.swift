import SwiftUI

/// The sheet that adds or edits a bill: amount, what for, who paid, how it's split and when.
/// Splitting equally among everyone is the default, so most bills need only the first two.
struct BillFormView: View {
    let group: SquabbleGroup
    let uid: String
    let onSave: (Bill, _ isNew: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: BillDraft
    /// What the sheet opened with, so it can tell whether anything would be lost.
    @State private var original: BillDraft
    @State private var isConfirmingDiscard = false
    @State private var isSplitting = false
    @FocusState private var focus: Field?

    private enum Field {
        case amount
        case title
    }

    init(draft: BillDraft, group: SquabbleGroup, uid: String, onSave: @escaping (Bill, _ isNew: Bool) -> Void) {
        self.group = group
        self.uid = uid
        self.onSave = onSave
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            form
                .background { Color.backdropDeep.ignoresSafeArea() }
                .navigationDestination(isPresented: $isSplitting) {
                    BillSplitView(draft: $draft, group: group, me: uid)
                        .background { Color.backdropDeep.ignoresSafeArea() }
                }
        }
        .tint(.white)
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 2) {
                    amountField
                    // A space keeps the line's height while there's nothing to say.
                    Text(verbatim: hint ?? " ")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                titleField
                details
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(.white)
        .navigationTitle(draft.isNew
            ? Text("Add a bill", comment: "Squabble page: button at the bottom that adds a bill.")
            : Text("Edit bill", comment: "Bill form: title when editing."))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel) {
                    if draft != original { isConfirmingDiscard = true } else { dismiss() }
                }
                .confirmationDialog(
                    Text("Discard this bill?", comment: "Bill form: title of the prompt when cancelling with something entered."),
                    isPresented: $isConfirmingDiscard,
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive) {
                        dismiss()
                    } label: {
                        Text("Discard", comment: "Create squabble: button in the cancel prompt that throws the entries away.")
                    }
                    Button(role: .cancel) {} label: {
                        Text("Keep editing", comment: "Create squabble: button in the cancel prompt that goes back to the sheet.")
                    }
                }
            }
        }
        .safeAreaBar(edge: .bottom) { saveBar }
        .interactiveDismissDisabled(draft != original)
        .onAppear {
            if draft.isNew, draft.amountText.isEmpty { focus = .amount }
        }
    }

    private var amountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            AmountField(text: draft.amountText, currencyCode: draft.currencyCode) { draft.setAmount($0) }
            .focused($focus, equals: .amount)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .fixedSize(horizontal: true, vertical: false)
            Text(verbatim: draft.currencyCode)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onTapGesture { focus = .amount }
    }

    private var titleField: some View {
        TextField(
            "Title",
            text: Binding(get: { draft.title }, set: { draft.setTitle($0) }),
            prompt: Text("What was it for?", comment: "Bill form: placeholder in the title field.")
                .foregroundStyle(.white.opacity(0.5))
        )
        .focused($focus, equals: .title)
        .submitLabel(.done)
        .onSubmit { focus = nil }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
        // The field itself is only as tall as its text.
        .contentShape(.rect)
        .onTapGesture { focus = .title }
    }

    private var details: some View {
        VStack(spacing: 0) {
            payerRow
            Divider().padding(.leading, 16)
            splitRow
            Divider().padding(.leading, 16)
            dateRow
        }
        .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
    }

    private var payerRow: some View {
        Menu {
            Picker(selection: $draft.paidBy) {
                ForEach(draft.candidates, id: \.self) { candidate in
                    Text(verbatim: name(candidate)).tag(candidate)
                }
            } label: {
                EmptyView()
            }
        } label: {
            row(
                title: Text("Paid by", comment: "Bill form: row that picks who paid."),
                value: Text(verbatim: name(draft.paidBy)),
                symbol: "chevron.up.chevron.down"
            )
        }
        .buttonStyle(.plain)
    }

    private var splitRow: some View {
        Button {
            focus = nil
            isSplitting = true
        } label: {
            row(
                title: Text("Split", comment: "Bill form: row that opens how the bill is split, and that page's title."),
                value: splitSummary,
                symbol: "chevron.right"
            )
        }
        .buttonStyle(.plain)
    }

    private var splitSummary: Text {
        switch draft.split {
        case .exactly:
            Text("By amounts", comment: "Bill form: the bill is split by amounts entered by hand.")
        case .equally where draft.includesEveryone:
            Text("Equally, everyone", comment: "Bill form: split equally among all members.")
        case .equally:
            Text("Equally, \(draft.included.count) of \(draft.candidates.count)", comment: "Bill form: split equally among some of the members; how many, of how many.")
        }
    }

    private var dateRow: some View {
        DatePicker(
            selection: Binding(get: { draft.date.date() }, set: { draft.date = CalendarDay($0) }),
            in: ...Date.now.addingTimeInterval(Self.halfDay),
            displayedComponents: .date
        ) {
            Text("Date", comment: "Bill form: row that picks the day of the bill.")
        }
        .colorScheme(.dark)
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }

    /// `CalendarDay` reads as midday, which is still to come in the morning; the picker would
    /// otherwise refuse today.
    private static let halfDay: TimeInterval = 12 * 60 * 60

    private func row(title: Text, value: Text, symbol: String) -> some View {
        HStack(spacing: 8) {
            title
            Spacer(minLength: 12)
            value
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .contentShape(.rect)
    }

    private var saveBar: some View {
        Button(action: save) {
            draft.isNew
                ? Text("Add bill", comment: "Bill form: button that saves a new bill.")
                : Text("Save changes", comment: "Bill form: button that saves an edited bill.")
        }
        .buttonStyle(.squabblePrimary)
        .disabled(!draft.canSave)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        // Keeps clear air between the button and the keyboard when it's up; the rows need
        // the rest.
        .padding(.bottom, 12)
        .frame(maxWidth: 560)
    }

    private var hint: String? {
        if let missing = draft.missing, missing.minorUnits != 0 { return BillSplitView.hint(missing: missing) }
        guard let effect = draft.effect(on: uid) else { return nil }
        if effect.minorUnits == 0 {
            return String(localized: "This one changes nothing for you", comment: "Bill form: under the amount; the bill doesn't affect the user's balance.")
        }
        return BillText.standing(effect)
    }

    private func name(_ candidate: String) -> String {
        BillText.name(of: candidate, in: group, me: uid)
    }

    private func save() {
        guard let bill = draft.makeBill(by: uid) else { return }
        onSave(bill, draft.isNew)
        dismiss()
    }
}
