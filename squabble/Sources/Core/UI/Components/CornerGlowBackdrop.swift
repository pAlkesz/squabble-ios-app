import SwiftUI

/// `SquabbleBackdrop`'s colours as a wavy glow out of the top-right corner, so a squabble's
/// pages don't look like home. The uneven mesh is deliberate: a clean diagonal gradient read
/// as too rigid. It drifts slowly; Reduce Motion pins it.
struct CornerGlowBackdrop: View {
    let palette: BackdropPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Driven by the clock so an animated palette change can't cancel the drift.
        TimelineView(.animation(paused: reduceMotion)) { context in
            MeshGradient(
                width: 3,
                height: 4,
                points: reduceMotion ? Self.resting : Self.points(at: context.date),
                colors: [
                    palette.mid, palette.high, palette.top,
                    palette.mid, palette.mid, palette.high,
                    palette.deep, palette.mid, palette.mid,
                    palette.deep, palette.deep, palette.deep,
                ]
            )
        }
        .ignoresSafeArea()
    }

    private static func points(at date: Date) -> [SIMD2<Float>] {
        let cycle = date.timeIntervalSinceReferenceDate / driftPeriod
        let progress = Float((1 - cos(2 * .pi * cycle)) / 2)
        return zip(resting, drifted).map { rest, drift in
            rest + (drift - rest) * progress
        }
    }

    private static let driftPeriod: TimeInterval = 22

    // The columns lean right so the bright corner stays behind the bar's trailing picture
    // and the title beside it keeps its contrast.
    private static let resting: [SIMD2<Float>] = [
        [0.0, 0.0], [0.72, 0.0], [1.0, 0.0],
        [0.0, 0.20], [0.54, 0.22], [1.0, 0.26],
        [0.0, 0.50], [0.52, 0.54], [1.0, 0.62],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
    ]

    private static let drifted: [SIMD2<Float>] = [
        [0.0, 0.0], [0.68, 0.0], [1.0, 0.0],
        [0.0, 0.23], [0.48, 0.25], [1.0, 0.31],
        [0.0, 0.46], [0.58, 0.49], [1.0, 0.68],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
    ]
}

#Preview {
    CornerGlowBackdrop(palette: .brand)
}
