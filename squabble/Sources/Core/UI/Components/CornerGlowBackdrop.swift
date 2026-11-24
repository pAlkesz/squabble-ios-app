import SwiftUI

/// `SquabbleBackdrop`'s colours as a wavy glow out of the top-right corner, so a squabble's
/// pages don't look like home. The uneven mesh is deliberate: a clean diagonal gradient read
/// as too rigid. It drifts slowly; Reduce Motion pins it.
struct CornerGlowBackdrop: View {
    let palette: BackdropPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = colors
        // Driven by the clock so an animated palette change can't cancel the drift.
        TimelineView(.animation(paused: reduceMotion)) { context in
            MeshGradient(
                width: Self.columns,
                height: Self.bands.count,
                points: Self.points(phase: reduceMotion ? 0 : Self.phase(at: context.date)),
                colors: colors
            )
        }
        .ignoresSafeArea()
    }

    /// Bands that fade towards the left, so the light still comes from the right corner.
    private var colors: [Color] {
        Self.bands.flatMap { band in
            (0..<Self.columns).map { column in
                let fromRight = 1 - Double(column) / Double(Self.columns - 1)
                return color(at: band.shade + fromRight * Self.leftwardFade)
            }
        }
    }

    /// 0 is the palette's brightest shade, 1 its deepest.
    private func color(at shade: Double) -> Color {
        switch shade {
        case ..<0.2: palette.top.mix(with: palette.high, by: shade / 0.2, in: .perceptual)
        case ..<0.5: palette.high.mix(with: palette.mid, by: (shade - 0.2) / 0.3, in: .perceptual)
        case ..<1: palette.mid.mix(with: palette.deep, by: (shade - 0.5) / 0.5, in: .perceptual)
        default: palette.deep
        }
    }

    private static let columns = 5
    private static let leftwardFade = 0.5

    /// Each band's height on the page, its shade at the right edge and how far it rolls. A
    /// lit band between darker ones is what makes the waves show; the edges stay put.
    private static let bands: [(y: Double, shade: Double, swell: Double)] = [
        (0, 0.05, 0), (0.17, 0.38, 0.05), (0.32, 0.22, 0.09),
        (0.47, 0.62, 0.09), (0.62, 0.48, 0.08), (0.80, 0.95, 0.06), (1, 1, 0),
    ]

    private static func phase(at date: Date) -> Double {
        // Sways back and forth rather than travelling, so it never reads as scrolling.
        sin(2 * .pi * date.timeIntervalSinceReferenceDate / driftPeriod) * 0.9
    }

    private static func points(phase: Double) -> [SIMD2<Float>] {
        bands.enumerated().flatMap { index, band in
            (0..<columns).map { column in
                let x = Double(column) / Double(columns - 1)
                let wave = sin(x * 1.5 * .pi + Double(index) * 0.6 + phase)
                return SIMD2(Float(x), Float(band.y + band.swell * wave))
            }
        }
    }

    private static let driftPeriod: TimeInterval = 22
}

#Preview {
    CornerGlowBackdrop(palette: .brand)
}
