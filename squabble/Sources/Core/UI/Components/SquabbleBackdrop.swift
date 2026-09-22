import SwiftUI

/// The app's dark background: a mesh of deep greens with one brighter node that drifts
/// slowly, so the screen breathes without anything obviously moving. Reduce Motion
/// pins the mesh to its resting shape.
struct SquabbleBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrifting = false

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: isDrifting && !reduceMotion ? Self.drifted : Self.resting,
            colors: Self.colors
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                isDrifting = true
            }
        }
    }

    private static let resting: [SIMD2<Float>] = [
        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
        [0.0, 0.5], [0.42, 0.38], [1.0, 0.5],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
    ]

    private static let drifted: [SIMD2<Float>] = [
        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
        [0.0, 0.46], [0.62, 0.56], [1.0, 0.58],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
    ]

    private static let colors: [Color] = [
        .backdropDeep, .backdropMid, .backdropDeep,
        .backdropMid, .backdropGlow, .backdropDeep,
        .backdropDeep, .backdropMid, .backdropDeep,
    ]
}

#Preview {
    SquabbleBackdrop()
}
