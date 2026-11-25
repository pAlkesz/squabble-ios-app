import SwiftUI

/// A squabble's backdrop: home's balance mood for this squabble's balance instead of the
/// total, glowing out of the corner where its picture sits. Neutral while the squabble is
/// loading or gone.
struct SquabbleMoodBackdrop: View {
    let groupID: String
    var isDimmed = false

    @Environment(GroupsStore.self) private var groups
    @Environment(RatesStore.self) private var rates
    @Environment(AuthSession.self) private var session
    #if DEBUG
    @Environment(DebugBalances.self) private var debugBalances: DebugBalances?
    #endif

    var body: some View {
        CornerGlowBackdrop(palette: isDimmed ? mood.palette.dimmed : mood.palette)
            .animation(.smooth(duration: 1.2), value: mood)
    }

    private var mood: BalanceMood {
        BalanceMood(
            amount: balance,
            currencyCode: groups.group(id: groupID)?.currencyCode ?? "EUR",
            rates: rates.rates
        )
    }

    private var balance: Decimal {
        #if DEBUG
        if let value = debugBalances?.values[groupID] {
            return Decimal(Int(value.rounded()))
        }
        #endif
        guard let uid = session.user?.id, let group = groups.group(id: groupID) else { return 0 }
        return group.balance(of: uid).amount
    }
}
