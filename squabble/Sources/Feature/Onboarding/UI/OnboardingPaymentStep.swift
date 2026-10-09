import SwiftUI

/// The payment slip as a live preview, tiles that open the editor for one kind of
/// payment method, then the added methods with a way to remove them.
struct OnboardingPaymentStep: View {
    @Binding var draft: OnboardingDraft
    @State private var editing: PaymentMethodEditor.Kind?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            OnboardingHeading(
                title: "Where should the money go?",
                subtitle: "Optional. Add a bank account or a payment link, and “I didn’t know how to pay you” stops being an excuse."
            )
            PaymentSlipView(
                name: draft.validDisplayName ?? "",
                methods: draft.paymentMethods
            )
            .padding(.horizontal, 4)
            if draft.canAddPaymentMethod {
                tiles
            }
            if !draft.paymentMethods.isEmpty {
                VStack(spacing: 12) {
                    ForEach(draft.paymentMethods) { method in
                        PaymentMethodRow(method: method) {
                            withAnimation { draft.paymentMethods.removeAll { $0.id == method.id } }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
            }
            // Reassurance about who sees the details only means something once there are some.
            if !draft.paymentMethods.isEmpty {
                Label("Only people you split bills with can see these. You can change them any time.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .sheet(item: $editing) { kind in
            PaymentMethodEditor(kind: kind, defaultHolderName: draft.validDisplayName ?? "") { method in
                withAnimation { draft.paymentMethods.append(method) }
            }
        }
    }

    // MARK: - Tiles

    private var tiles: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a way to pay you")
                .font(.headline)
            HStack(spacing: 10) {
                tile(.bankAccount, symbol: "building.columns.fill") {
                    Text("Bank", comment: "Payment quick-add tile: bank account.")
                }
                ForEach(PaymentProvider.allCases, id: \.self) { provider in
                    tile(.link(provider), symbol: provider.monogramSymbol) {
                        Text(verbatim: provider.name)
                    }
                }
            }
        }
    }

    private func tile(_ kind: PaymentMethodEditor.Kind, symbol: String, @ViewBuilder label: () -> Text) -> some View {
        Button {
            editing = kind
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2)
                label()
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

private extension PaymentProvider {
    /// A letter in a circle rather than the company's logo: recognisable enough, and no
    /// trademark artwork shipped in the app.
    var monogramSymbol: String {
        switch self {
        case .revolut: "r.circle.fill"
        case .paypal: "p.circle.fill"
        case .wise: "w.circle.fill"
        }
    }
}
