import SwiftUI

/// A currency's flag as a disc: the flag emoji enlarged until it fills the circle, or a
/// coin for currencies without one country.
struct CurrencyFlag: View {
    let option: CurrencyOption
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let flag = option.flag {
                // Emoji flags are wider than tall and drawn with some padding; at 1.5× the
                // disc's size the flag covers it fully and the crop keeps the middle.
                Text(verbatim: flag)
                    .font(.system(size: size * 1.5))
                    .fixedSize()
            } else {
                Image(systemName: "banknote")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(.white.opacity(0.14))
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
