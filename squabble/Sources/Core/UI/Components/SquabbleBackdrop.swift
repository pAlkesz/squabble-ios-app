import SwiftUI

/// The app's background: a steep vertical ramp from a bright brand green at the top
/// into deep green at the bottom — dark, but never black. The mesh's middle rows drift
/// slowly so the screen breathes without anything obviously moving; Reduce Motion pins
/// them to their resting shape.
struct SquabbleBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrifting = false

    var body: some View {
        MeshGradient(
            width: 3,
            height: 4,
            points: isDrifting && !reduceMotion ? Self.drifted : Self.resting,
            colors: Self.colors
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                isDrifting = true
            }
        }
    }

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

    private static let colors: [Color] = [
        .backdropTop, .backdropTop, .backdropTop,
        .backdropHigh, .backdropHigh, .backdropHigh,
        .backdropMid, .backdropMid, .backdropMid,
        .backdropDeep, .backdropDeep, .backdropDeep,
    ]
}

#Preview {
    SquabbleBackdrop()
}
