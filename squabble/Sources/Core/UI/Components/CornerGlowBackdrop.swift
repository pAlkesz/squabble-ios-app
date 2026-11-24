import SwiftUI

/// `SquabbleBackdrop`'s colours as a glow from the top-right corner, falling diagonally to
/// the bottom left, so a squabble's pages don't look like home. The glow breathes slowly;
/// Reduce Motion holds it still.
struct CornerGlowBackdrop: View {
    let palette: BackdropPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let radius = hypot(geometry.size.width, geometry.size.height)
            // Driven by the clock so an animated palette change can't cancel the drift.
            TimelineView(.animation(paused: reduceMotion)) { context in
                RadialGradient(
                    stops: [
                        .init(color: palette.top, location: 0),
                        .init(color: palette.high, location: 0.12),
                        .init(color: palette.mid, location: 0.40),
                        .init(color: palette.deep, location: 1),
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: radius * (reduceMotion ? 0.9 : Self.reach(at: context.date))
                )
            }
        }
        .ignoresSafeArea()
    }

    private static func reach(at date: Date) -> Double {
        let cycle = date.timeIntervalSinceReferenceDate / driftPeriod
        return 0.9 + 0.06 * sin(2 * .pi * cycle)
    }

    private static let driftPeriod: TimeInterval = 22
}

#Preview {
    CornerGlowBackdrop(palette: .brand)
}
