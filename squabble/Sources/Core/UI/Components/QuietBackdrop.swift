import SwiftUI

/// For pages about money that have no balance of their own: the dark half of the neutral
/// petrol, without a bright end. A bright fade always stands for a balance.
struct QuietBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [.balanceNeutralMid, .balanceNeutralDeep],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    QuietBackdrop()
}
