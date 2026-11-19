import SwiftUI

/// The invite link as a QR code in the app's style: round dots, rounded finder squares, and
/// the squabble's picture over the middle (the code is generated with high error correction
/// to allow for it).
struct InviteQRCode: View {
    let matrix: QRMatrix
    let image: SquabbleImage
    var size: CGFloat = 240

    var body: some View {
        Canvas { context, canvas in
            let module = canvas.width / CGFloat(matrix.size)
            let hidden = hiddenRange
            for y in 0..<matrix.size {
                for x in 0..<matrix.size where matrix.isDark(x: x, y: y) && !matrix.isFinder(x: x, y: y) {
                    if hidden.contains(x) && hidden.contains(y) { continue }
                    let dot = CGRect(x: CGFloat(x) * module, y: CGFloat(y) * module, width: module, height: module)
                        .insetBy(dx: module * 0.1, dy: module * 0.1)
                    context.fill(Path(ellipseIn: dot), with: .color(.white))
                }
            }
            for (x, y) in [(0, 0), (matrix.size - 7, 0), (0, matrix.size - 7)] {
                let origin = CGPoint(x: CGFloat(x) * module, y: CGFloat(y) * module)
                let outer = CGRect(origin: origin, size: CGSize(width: module * 7, height: module * 7))
                    .insetBy(dx: module / 2, dy: module / 2)
                context.stroke(Path(roundedRect: outer, cornerRadius: module * 2), with: .color(.white), lineWidth: module)
                let inner = CGRect(origin: origin, size: CGSize(width: module * 7, height: module * 7))
                    .insetBy(dx: module * 2, dy: module * 2)
                context.fill(Path(roundedRect: inner, cornerRadius: module * 0.9), with: .color(.white))
            }
        }
        .frame(width: size, height: size)
        .overlay {
            SquabbleImageView(image, size: size * CGFloat(hiddenRange.count - 1) / CGFloat(matrix.size))
        }
        .accessibilityElement()
        .accessibilityLabel(Text("QR code for the invite link", comment: "Invite sheet: VoiceOver label for the QR code."))
    }

    /// The square of modules under the picture: about a quarter of the width, centred.
    private var hiddenRange: ClosedRange<Int> {
        let span = max(5, matrix.size / 4) | 1
        let start = (matrix.size - span) / 2
        return start...(start + span - 1)
    }
}
