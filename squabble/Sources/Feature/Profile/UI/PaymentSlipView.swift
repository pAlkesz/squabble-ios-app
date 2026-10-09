import SwiftUI

/// How friends will see someone's payment details, as a pre-printed payment slip — a
/// nod to the Hungarian yellow postal cheque. The form's own printing (labels, boxes,
/// stamp) is in `slipPrint`; the details are "typed" over it in receipt ink.
struct PaymentSlipView: View {
    let name: String
    let methods: [PaymentMethod]

    /// Longer accounts (a full IBAN) don't fit one box per character on a phone.
    private static let maxBoxedCharacters = 17
    private static let labelWidth: CGFloat = 86

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            field(Text("Beneficiary", comment: "Payment slip: field label.")) {
                typed(beneficiary)
            }
            field(Text("Account no.", comment: "Payment slip: field label, abbreviated as on a printed form.")) {
                account
            }
            field(Text("Amount", comment: "Payment slip: field label.")) {
                Text("Whatever you owe.", comment: "Payment slip: the amount field, filled in.")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .italic()
                    .foregroundStyle(Color.receiptInk)
            }
            if methods.isEmpty {
                Text(
                    "Nobody can pay you yet. Very convenient for them.",
                    comment: "Payment slip: shown before any payment method is added."
                )
                .font(.system(.caption2, design: .monospaced))
                .italic()
                .foregroundStyle(Color.receiptInk.opacity(0.7))
            }
            ForEach(alsoAccepts) { method in
                field(Text("Also accepts", comment: "Payment slip: label for any extra payment methods.")) {
                    typed(value(for: method))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color.slipPaper, in: .rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.slipPrint.opacity(0.35), lineWidth: 1)
                .padding(5)
        }
        .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 10)
        .rotationEffect(.degrees(-1.2))
        .animation(.snappy, value: methods)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Parts

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PAYMENT SLIP", comment: "Payment slip: printed title. In Hungarian, the yellow cheque everyone knows.")
                    .font(.system(.headline, design: .monospaced, weight: .heavy))
                    .kerning(2)
                Text("Keep for your records. Or don't.", comment: "Payment slip: small print under the title.")
                    .font(.system(.caption2, design: .monospaced))
                    .opacity(0.8)
            }
            Spacer(minLength: 8)
            stamp
        }
        .foregroundStyle(Color.slipPrint)
    }

    private var stamp: some View {
        SquabLogoView(color: .slipPrint)
            .padding(9)
            .frame(width: 52, height: 52)
            .overlay {
                Circle().strokeBorder(Color.slipPrint, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            }
            .rotationEffect(.degrees(12))
            .opacity(0.8)
    }

    private func field(_ label: Text, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 8) {
            label
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(Color.slipPrint)
                .frame(width: Self.labelWidth, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(.white.opacity(0.45), in: .rect(cornerRadius: 2))
                .overlay {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(Color.slipPrint.opacity(0.6), lineWidth: 0.75)
                }
        }
    }

    @ViewBuilder
    private var account: some View {
        if let accountText {
            if accountText.count <= Self.maxBoxedCharacters {
                digitBoxes(accountText)
            } else {
                typed(accountText)
            }
        } else {
            typed("—")
        }
    }

    /// One box per character, like the account-number grid printed on the real thing.
    private func digitBoxes(_ text: String) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(verbatim: String(character))
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Color.receiptInk)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(Color.slipPrint.opacity(0.35)).frame(width: 0.5)
                    }
            }
        }
        .minimumScaleFactor(0.7)
    }

    private func typed(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(.caption, design: .monospaced, weight: .semibold))
            .foregroundStyle(Color.receiptInk)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    // MARK: - Content

    private var primaryBank: (iban: IBAN, holderName: String)? {
        for method in methods {
            if case .bankAccount(let iban, let holderName) = method.kind { return (iban, holderName) }
        }
        return nil
    }

    /// A transfer goes to the account holder, which may not be the profile's name.
    private var beneficiary: String {
        primaryBank?.holderName ?? name
    }

    private var accountText: String? {
        primaryBank?.iban.preferredFormat()
    }

    private var alsoAccepts: [PaymentMethod] {
        var skippedPrimary = false
        return methods.filter { method in
            if case .bankAccount = method.kind, !skippedPrimary {
                skippedPrimary = true
                return false
            }
            return true
        }
    }

    private func value(for method: PaymentMethod) -> String {
        switch method.kind {
        case .bankAccount(let iban, _): iban.preferredFormat()
        case .link(let link): link.provider.linkPrefixes[0] + link.username
        }
    }
}
