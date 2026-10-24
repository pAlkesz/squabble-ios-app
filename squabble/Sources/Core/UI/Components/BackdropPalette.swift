import SwiftUI

/// The four rows of `SquabbleBackdrop`'s mesh, bright at the top of the screen down to
/// near-black at the bottom. `.brand` is the app's green; other screens can tint it.
struct BackdropPalette: Equatable {
    let top: Color
    let high: Color
    let mid: Color
    let deep: Color

    static let brand = BackdropPalette(
        top: .backdropTop,
        high: .backdropHigh,
        mid: .backdropMid,
        deep: .backdropDeep
    )

    /// Blends row by row in a perceptual space, so a mix of amber and red stays warm
    /// instead of going muddy brown halfway.
    func mixed(with other: BackdropPalette, by fraction: Double) -> BackdropPalette {
        BackdropPalette(
            top: top.mix(with: other.top, by: fraction, in: .perceptual),
            high: high.mix(with: other.high, by: fraction, in: .perceptual),
            mid: mid.mix(with: other.mid, by: fraction, in: .perceptual),
            deep: deep.mix(with: other.deep, by: fraction, in: .perceptual)
        )
    }
}
