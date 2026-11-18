import SwiftUI

/// One currency in a picker list: its flag, a title, "HUF · Hungary" underneath, and a
/// checkmark when it's the current choice.
struct CurrencyRow: View {
    let flag: CurrencyOption
    let title: Text
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    /// "HUF · Hungary", or just the code when no single country goes with it.
    static func detail(for option: CurrencyOption) -> String {
        option.countryName.map { "\(option.code) · \($0)" } ?? option.code
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                CurrencyFlag(option: flag)
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(.body.weight(.semibold))
                    Text(verbatim: detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accent)
                    .opacity(isSelected ? 1 : 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.white.opacity(0.08))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
