import SwiftUI

struct PaymentMethodRow: View {
    let method: PaymentMethod
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.14), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.body.weight(.semibold))
                Text(verbatim: detail)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            if let onDelete {
                Button("Remove", systemImage: "trash", role: .destructive, action: onDelete)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(14)
        .background(.white.opacity(0.1), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch method.kind {
        case .bankAccount: "building.columns"
        case .link: "link"
        }
    }

    private var title: String {
        switch method.kind {
        case .bankAccount(_, let holderName): holderName
        case .link(let link): link.provider.name
        }
    }

    private var detail: String {
        switch method.kind {
        case .bankAccount(let iban, _): iban.formatted
        case .link(let link): link.provider.linkPrefixes[0] + link.username
        }
    }
}
