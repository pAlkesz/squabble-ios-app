import CoreGraphics

/// Shared layout values, so screens built at different times still line up.
enum SquabbleMetrics {
    /// Corners of every row, card, list group and input field: iOS 27's own grouped lists
    /// draw theirs at about 28 pt (measured), and SwiftUI can't change that, so custom
    /// surfaces match it instead. Props (the membership card, the payment slip, the stamp)
    /// keep their own.
    static let cornerRadius: CGFloat = 28
}
