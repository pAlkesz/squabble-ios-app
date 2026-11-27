import SwiftUI

/// The logo bird hopping on the spot while something loads: it crouches, springs up with a
/// flap and the receipt swinging in its beak, and lands with a little squash over its own
/// shadow. The hop moves the whole mark (moving the body piece alone tears the silhouette
/// apart); only the wing, tail and receipt move on their own. Reduce Motion: a slow pulse.
struct HoppingBirdView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            SquabLogoView(color: .white)
                .phaseAnimator([1.0, 0.45]) { content, opacity in
                    content.opacity(opacity)
                } animation: { _ in .easeInOut(duration: 0.9) }
        } else {
            PhaseAnimator(Phase.allCases) { phase in
                VStack(spacing: 6) {
                    SquabLogoView(color: .white, pose: { phase.pose(for: $0) }, animation: { _ in phase.animation })
                        .scaleEffect(x: phase.stretch.width, y: phase.stretch.height, anchor: .bottom)
                        .offset(y: phase.lift)
                    Ellipse()
                        .fill(.black.opacity(phase.lift < 0 ? 0.12 : 0.22))
                        .frame(height: 6)
                        .scaleEffect(x: phase.lift < 0 ? 0.6 : 0.9)
                }
            } animation: { phase in
                phase.animation
            }
        }
    }

    private enum Phase: CaseIterable {
        case rest, crouch, air, land

        /// Upwards in points; the logo is drawn small enough that a fixed hop reads well.
        var lift: CGFloat {
            self == .air ? -16 : 0
        }

        var stretch: CGSize {
            switch self {
            case .rest: CGSize(width: 1, height: 1)
            case .crouch: CGSize(width: 1.04, height: 0.9)
            case .air: CGSize(width: 0.97, height: 1.05)
            case .land: CGSize(width: 1.05, height: 0.92)
            }
        }

        var animation: Animation {
            switch self {
            case .rest: .spring(duration: 0.35, bounce: 0.3)
            case .crouch: .easeOut(duration: 0.16)
            case .air: .easeOut(duration: 0.24)
            case .land: .easeIn(duration: 0.2)
            }
        }

        func pose(for piece: SquabLogoPiece) -> SquabLogoPiecePose {
            let beak = SquabLogoPieceShape.anchor(for: SquabLogoPiece.beakTip)
            let wing = SquabLogoPieceShape.anchor(for: SquabLogoPiece.wingJoint)
            switch (self, piece) {
            case (.air, .wing): return SquabLogoPiecePose(rotation: .degrees(-16), anchor: wing)
            case (.land, .wing): return SquabLogoPiecePose(rotation: .degrees(5), anchor: wing)
            case (.air, .receipt): return SquabLogoPiecePose(rotation: .degrees(10), anchor: beak)
            case (.air, .receiptCurl): return SquabLogoPiecePose(rotation: .degrees(16), anchor: beak)
            case (.land, .receipt): return SquabLogoPiecePose(rotation: .degrees(-6), anchor: beak)
            case (.land, .receiptCurl): return SquabLogoPiecePose(rotation: .degrees(-9), anchor: beak)
            case (.air, .tailUpper): return SquabLogoPiecePose(rotation: .degrees(5), anchor: .trailing)
            case (.air, .tailLower): return SquabLogoPiecePose(rotation: .degrees(8), anchor: .trailing)
            default: return .identity
            }
        }
    }
}

#Preview {
    ZStack {
        SquabbleBackdrop()
        HoppingBirdView().frame(width: 90)
    }
}
