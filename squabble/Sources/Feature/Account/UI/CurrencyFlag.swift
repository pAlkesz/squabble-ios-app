import SwiftUI

/// A currency's flag as a disc, from the round flags in the asset catalog (circle-flags, see
/// THIRD_PARTY_NOTICES.md), or a banknote for currencies without one country.
struct CurrencyFlag: View {
    let option: CurrencyOption
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let asset = option.flagAssetName {
                Image(asset)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "banknote")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.14))
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
