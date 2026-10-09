import SwiftUI

/// The headline number on home: everything the user is owed minus everything they owe,
/// in one currency. Whole units are set large and the rest (decimals, currency symbol)
/// small, so the number reads at a glance in any locale's currency format.
struct TotalBalanceView: View {
    let amount: Decimal
    let currencyCode: String

    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 4) {
            Text("Total · \(currencyCode)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            Text(formattedAmount)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: NSDecimalNumber(decimal: amount).doubleValue))
        }
        .accessibilityElement(children: .combine)
    }

    private var formattedAmount: AttributedString {
        var text = amount.formatted(.currency(code: currencyCode).attributed)
        let large = Font.system(size: amountSize, weight: .bold, design: .rounded)
        let small = Font.system(size: amountSize * 0.55, weight: .bold, design: .rounded)
        for run in text.runs {
            let isLarge = run.numberPart == .integer
                || run.numberSymbol == .groupingSeparator
                || run.numberSymbol == .sign
            text[run.range].font = isLarge ? large : small
        }
        return text
    }
}

#Preview {
    VStack(spacing: 32) {
        TotalBalanceView(amount: Decimal(string: "48083.16") ?? 0, currencyCode: "HUF")
        TotalBalanceView(amount: Decimal(string: "-1250.5") ?? 0, currencyCode: "EUR")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { SquabbleBackdrop() }
}
