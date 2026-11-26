import SwiftUI

/// For pages about money that have no balance of their own (the squabbles list): a plain
/// slate blue fade, a hue no balance mood uses, so the mood-tinted rows on it stand out. A
/// bright fade always stands for a balance.
struct QuietBackdrop: View {
    var body: some View {
        LinearGradient(colors: [.quietTop, .quietDeep], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

#Preview {
    QuietBackdrop()
}
