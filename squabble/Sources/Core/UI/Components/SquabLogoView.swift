import SwiftUI

/// A transform applied to one piece of the bird. `offset` is in multiples of the
/// logo's own size, so poses are resolution-independent; `anchor` is in the logo's
/// unit space (see `SquabLogoPieceShape.anchor(for:)`).
struct SquabLogoPiecePose: Equatable {
    var offset: CGSize = .zero
    var rotation: Angle = .zero
    var anchor: UnitPoint = .center
    var scale: CGFloat = 1
    var opacity: Double = 1

    static let identity = SquabLogoPiecePose()
}

/// The Squabble bird, drawn as stacked paper-cut pieces. With the default closures it
/// is the static brand mark; callers can pose and animate each piece independently.
struct SquabLogoView: View {
    var color: Color = .white
    var pose: (SquabLogoPiece) -> SquabLogoPiecePose = { _ in .identity }
    var animation: (SquabLogoPiece) -> Animation? = { _ in nil }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(SquabLogoPiece.allCases, id: \.self) { piece in
                    let pose = pose(piece)
                    SquabLogoPieceShape(piece: piece)
                        .fill(color, style: FillStyle(eoFill: true))
                        .scaleEffect(pose.scale, anchor: pose.anchor)
                        .rotationEffect(pose.rotation, anchor: pose.anchor)
                        .offset(
                            x: pose.offset.width * proxy.size.width,
                            y: pose.offset.height * proxy.size.height
                        )
                        .opacity(pose.opacity)
                        .animation(animation(piece), value: pose)
                }
            }
        }
        .aspectRatio(SquabLogoPiece.aspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    SquabLogoView()
        .padding(40)
        .background(Color.accentColor)
}
