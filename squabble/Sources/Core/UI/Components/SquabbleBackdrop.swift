import SwiftUI

/// The app's background: a steep vertical ramp from a bright colour at the top into a
/// deep shade at the bottom — dark, but never black. Brand green unless a screen passes
/// another palette (home tints it by the balance). The mesh's middle rows drift slowly
/// so the screen breathes without anything obviously moving; Reduce Motion pins them
/// to their resting shape.
struct SquabbleBackdrop: View {
    var palette: BackdropPalette = .brand

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The drift is computed from the clock rather than run as a repeating animation,
        // so an animated palette change can't cancel it: both would animate the same mesh.
        TimelineView(.animation(paused: reduceMotion)) { context in
            MeshGradient(
                width: 3,
                height: 4,
                points: reduceMotion ? Self.resting : Self.points(at: context.date),
                colors: colors
            )
        }
        .ignoresSafeArea()
    }

    private var colors: [Color] {
        [
            palette.top, palette.top, palette.top,
            palette.high, palette.high, palette.high,
            palette.mid, palette.mid, palette.mid,
            palette.deep, palette.deep, palette.deep,
        ]
    }

    /// Eases from resting to drifted and back over `driftPeriod`.
    private static func points(at date: Date) -> [SIMD2<Float>] {
        let cycle = date.timeIntervalSinceReferenceDate / driftPeriod
        let progress = Float((1 - cos(2 * .pi * cycle)) / 2)
        return zip(resting, drifted).map { rest, drift in
            rest + (drift - rest) * progress
        }
    }

    private static let driftPeriod: TimeInterval = 22

    // Rows sit at y = 0, 0.13, 0.40, 1 so the bright band stays above the content and
    // the ramp falls off fast enough to read as a gradient rather than a wash.
    private static let resting: [SIMD2<Float>] = [
        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
        [0.0, 0.13], [0.46, 0.11], [1.0, 0.15],
        [0.0, 0.40], [0.54, 0.38], [1.0, 0.42],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
    ]

    private static let drifted: [SIMD2<Float>] = [
        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
        [0.0, 0.16], [0.58, 0.15], [1.0, 0.11],
        [0.0, 0.43], [0.42, 0.44], [1.0, 0.37],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
    ]
}

#Preview {
    SquabbleBackdrop()
}
