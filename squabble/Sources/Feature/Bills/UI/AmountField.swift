import SwiftUI

/// A text field that only holds what can be an amount in its currency. Keeps its own copy of
/// the text: a binding that quietly rejects input leaves the rejected characters on screen.
struct AmountField: View {
    let text: String
    let currencyCode: String
    let onChange: (String) -> Void

    @State private var typed: String

    init(text: String, currencyCode: String, onChange: @escaping (String) -> Void) {
        self.text = text
        self.currencyCode = currencyCode
        self.onChange = onChange
        _typed = State(initialValue: text)
    }

    var body: some View {
        TextField("Amount", text: $typed, prompt: Text(verbatim: "0").foregroundStyle(.white.opacity(0.4)))
            .keyboardType(CurrencyPrecision.fractionDigits(for: currencyCode) == 0 ? .numberPad : .decimalPad)
            .onChange(of: typed) { _, input in
                let clean = AmountInput.sanitized(input, currencyCode: currencyCode)
                if clean != input { typed = clean }
                if clean != text { onChange(clean) }
            }
            .onChange(of: text) { _, text in
                if text != typed { typed = text }
            }
    }
}
