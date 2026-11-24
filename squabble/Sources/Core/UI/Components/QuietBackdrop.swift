import SwiftUI

/// For pages about money that have no balance of their own: a dark aubergine, a hue
/// no balance mood uses. A bright fade always stands for a balance.
struct QuietBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [.quietTop, .quietDeep],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    QuietBackdrop()
}
