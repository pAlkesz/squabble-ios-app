#if DEBUG
import SwiftUI

/// Pretend balances by squabble id, so every backdrop mood can be seen on a device. Shared
/// by a squabble's pages, hence not view state.
@Observable
final class DebugBalances {
    var values: [String: Double] = [:]

    func toggle(_ groupID: String) {
        values[groupID] = values[groupID] == nil ? 0 : nil
    }
}

/// Shown after long-pressing a squabble's name.
struct DebugBalanceSlider: View {
    let groupID: String
    let currencyCode: String

    @Environment(DebugBalances.self) private var balances: DebugBalances?

    var body: some View {
        if let balances, let value = balances.values[groupID] {
            let range = 300 * BalanceMood.unitsPerEuro(currencyCode)
            Slider(
                value: Binding(get: { value }, set: { balances.values[groupID] = $0 }),
                in: -range...range
            )
            .tint(.white)
            .padding(.horizontal, 24)
        }
    }
}
#endif
