import SwiftUI

/// Draws one piece of the bird, fitting `SquabLogoPiece.canvas` into the rect so every
/// piece shares the same coordinate space and can be stacked without extra layout.
/// Fill with `FillStyle(eoFill: true)` so cutouts read as holes.
nonisolated struct SquabLogoPieceShape: Shape {
    let piece: SquabLogoPiece

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(piece.polygon)
        path.closeSubpath()
        for cutout in piece.cutouts {
            path.addEllipse(in: cutout)
        }
        return path.applying(Self.transform(fitting: SquabLogoPiece.canvas, into: rect))
    }

    /// Maps a canvas-space point to the unit-square anchor SwiftUI expects.
    static func anchor(for point: CGPoint) -> UnitPoint {
        let canvas = SquabLogoPiece.canvas
        return UnitPoint(
            x: (point.x - canvas.minX) / canvas.width,
            y: (point.y - canvas.minY) / canvas.height
        )
    }

    private static func transform(fitting canvas: CGRect, into rect: CGRect) -> CGAffineTransform {
        let scale = min(rect.width / canvas.width, rect.height / canvas.height)
        let fitted = CGSize(width: canvas.width * scale, height: canvas.height * scale)
        let origin = CGPoint(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2
        )
        return CGAffineTransform(translationX: origin.x, y: origin.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -canvas.minX, y: -canvas.minY)
    }
}
