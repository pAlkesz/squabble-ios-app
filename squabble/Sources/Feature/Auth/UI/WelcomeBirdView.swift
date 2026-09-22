import SwiftUI

/// The brand mark on the welcome screen, with one secret: tap it and the bird ruffles
/// up and chirps, nearly dropping the receipt. Costs nothing, rewards the curious.
/// Reduce Motion keeps the chirp and skips the movement.
struct WelcomeBirdView: View {
    var sounds: any LaunchSoundPlaying = LaunchSoundPlayer()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRuffled = false

    var body: some View {
        SquabLogoView(color: .white, pose: pose(for:), animation: { _ in reaction })
            .aspectRatio(SquabLogoPiece.aspectRatio, contentMode: .fit)
            // The hop rides on the whole mark: moving the body piece on its own tears
            // the silhouette away from the wing and tail.
            .offset(y: isRuffled && !reduceMotion ? -6 : 0)
            .animation(reaction, value: isRuffled)
            .contentShape(Rectangle())
            .onTapGesture(perform: ruffle)
            .accessibilityIdentifier("welcome.bird")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Squabble", comment: "App name, read by VoiceOver for the welcome-screen bird."))
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Annoys the bird.", comment: "VoiceOver hint for the tappable welcome-screen bird."))
            .accessibilityAction(.default, ruffle)
    }

    private var reaction: Animation {
        .spring(response: 0.26, dampingFraction: 0.42)
    }

    private func pose(for piece: SquabLogoPiece) -> SquabLogoPiecePose {
        guard isRuffled, !reduceMotion else { return .identity }
        switch piece {
        case .wing:
            return SquabLogoPiecePose(
                rotation: .degrees(-9),
                anchor: SquabLogoPieceShape.anchor(for: SquabLogoPiece.wingJoint)
            )
        case .receipt:
            return SquabLogoPiecePose(
                rotation: .degrees(11),
                anchor: SquabLogoPieceShape.anchor(for: SquabLogoPiece.beakTip)
            )
        case .receiptCurl:
            return SquabLogoPiecePose(
                rotation: .degrees(16),
                anchor: SquabLogoPieceShape.anchor(for: SquabLogoPiece.beakTip)
            )
        case .body:
            return .identity
        case .tailUpper:
            return SquabLogoPiecePose(rotation: .degrees(4), anchor: .trailing)
        case .tailLower:
            return SquabLogoPiecePose(rotation: .degrees(6), anchor: .trailing)
        }
    }

    private func ruffle() {
        guard !isRuffled else { return }
        isRuffled = true
        Task {
            await sounds.prepare()
            await sounds.play(.hop)
        }
        Task {
            try? await Task.sleep(for: .seconds(0.42))
            isRuffled = false
        }
    }
}

#Preview {
    ZStack {
        SquabbleBackdrop()
        WelcomeBirdView().frame(width: 160)
    }
}
