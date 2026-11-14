import SwiftUI

/// The account pages' background: the dark half of the brand ramp, with a faint green glow
/// up where the membership card sits. Quieter than `SquabbleBackdrop`'s bright top, and
/// deliberately not home's balance mood: these pages are about the person, not their debts.
struct ProfileBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.backdropMid, .backdropDeep], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Color.backdropHigh.opacity(0.45), .clear],
                center: UnitPoint(x: 0.5, y: 0.22),
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}
