import SwiftUI

/// A paper rectangle whose bottom edge is torn off a printer roll. The top stays
/// straight — the strip reads as still feeding out of the machine.
nonisolated struct TornPaperShape: Shape {
    var toothWidth: CGFloat = 14
    var toothHeight: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let teeth = max(1, Int((rect.width / toothWidth).rounded()))
        let width = rect.width / CGFloat(teeth)
        let baseline = rect.maxY - toothHeight

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: baseline))
        for tooth in stride(from: teeth - 1, through: 0, by: -1) {
            let leading = rect.minX + CGFloat(tooth) * width
            path.addLine(to: CGPoint(x: leading + width / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: leading, y: baseline))
        }
        path.closeSubpath()
        return path
    }
}
