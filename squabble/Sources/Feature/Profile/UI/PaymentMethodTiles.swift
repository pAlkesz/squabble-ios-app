import SwiftUI

/// A row of glass tiles, one per kind of payment method, each asking to add that kind.
struct PaymentMethodTiles: View {
    let onChoose: (PaymentMethodEditor.Kind) -> Void

    var body: some View {
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
            onChoose(kind)
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
