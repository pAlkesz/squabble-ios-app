import SwiftUI

/// A chat bubble: a rounded rectangle, with a small curled tail out of its bottom corner on
/// the speaker's side when it's the last of a run (as Revolut's and iMessage's chats do).
/// The tail reaches `tailWidth` past the frame, so the bubble's neighbours keep their spacing.
nonisolated struct ChatBubbleShape: Shape {
    enum Tail {
        case none
        case leading
        case trailing
    }

    var tail: Tail
    var cornerRadius: CGFloat = SquabbleMetrics.bubbleCornerRadius

    static let tailWidth: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let body = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        guard tail != .none else { return body }
        let tailPath = Self.leadingTail(in: rect)
        let placed = tail == .leading
            ? tailPath
            : tailPath.applying(CGAffineTransform(translationX: rect.minX + rect.maxX, y: 0).scaledBy(x: -1, y: 1))
        return body.union(placed)
    }

    /// Fills the bottom-left corner and flares out past the edge to a point on the baseline.
    private static func leadingTail(in rect: CGRect) -> Path {
        let x = rect.minX, bottom = rect.maxY
        var path = Path()
        path.move(to: CGPoint(x: x, y: bottom - 18))
        path.addCurve(
            to: CGPoint(x: x - tailWidth, y: bottom),
            control1: CGPoint(x: x, y: bottom - 6),
            control2: CGPoint(x: x - 2, y: bottom - 1)
        )
        path.addCurve(
            to: CGPoint(x: x + 16, y: bottom - 3),
            control1: CGPoint(x: x + 3, y: bottom + 0.5),
            control2: CGPoint(x: x + 10, y: bottom - 0.5)
        )
        path.addLine(to: CGPoint(x: x + 16, y: bottom - 18))
        path.closeSubpath()
        return path
    }
}
