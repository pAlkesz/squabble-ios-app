import SwiftUI

/// For pages about money that have no balance of their own: plum in slow, uneven
/// waves, a hue no balance mood uses. A bright fade always stands for a balance. Reduce Motion
/// pins the waves.
struct QuietBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            MeshGradient(
                width: Self.columns,
                height: Self.rows.count,
                points: Self.points(phase: reduceMotion ? 0 : Self.phase(at: context.date)),
                colors: [Color.quietTop, .quietMid, .quietTop, .quietMid, .quietDeep, .quietDeep]
                    .flatMap { Array(repeating: $0, count: Self.columns) }
            )
        }
        .ignoresSafeArea()
    }

    private static let columns = 5

    /// Where each band of colour sits and how far it rolls up and down; the edges stay put.
    private static let rows: [(y: Double, swell: Double)] = [
        (0, 0), (0.18, 0.06), (0.38, 0.09), (0.58, 0.08), (0.80, 0.06), (1, 0),
    ]

    private static func phase(at date: Date) -> Double {
        // Sways back and forth rather than travelling, so it never reads as scrolling.
        sin(2 * .pi * date.timeIntervalSinceReferenceDate / driftPeriod) * 0.9
    }

    private static func points(phase: Double) -> [SIMD2<Float>] {
        rows.enumerated().flatMap { index, row in
            (0..<columns).map { column in
                let x = Double(column) / Double(columns - 1)
                let wave = sin(x * 1.5 * .pi + Double(index) * 0.7 + phase)
                return SIMD2(Float(x), Float(row.y + row.swell * wave))
            }
        }
    }

    private static let driftPeriod: TimeInterval = 22
}

#Preview {
    QuietBackdrop()
}
