import SwiftUI

/// The animated hand-off from the static launch screen: it starts as the same plain
/// green field, assembles the bird out of paper pieces, then the bird flies off with
/// the receipt and the field fades to reveal the app.
/// Tapping skips straight to the fade. Reduce Motion replaces the choreography with
/// a plain cross-fade.
struct LaunchSplashView: View {
    let onFinished: @MainActor () -> Void
    var sounds: any LaunchSoundPlaying = LaunchSoundPlayer()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = LaunchPhase.curtain
    @State private var skipped = false

    var body: some View {
        ZStack {
            Color.accentColor
            logo
                .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
        .opacity(phase == .done ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: phase)
        .contentShape(Rectangle())
        .onTapGesture(perform: skip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Squabble", comment: "App name, read by VoiceOver on the launch splash."))
        .accessibilityAddTraits(.isImage)
        .accessibilityAction(named: Text("Skip intro", comment: "VoiceOver action to skip the launch animation."), skip)
        .task(play)
    }

    // MARK: - Logo

    private var logo: some View {
        SquabLogoView(pose: pose(for:), animation: animation(for:))
            .frame(maxWidth: 320)
            .rotationEffect(.degrees(isFlyingAway && !reduceMotion ? -14 : 0))
            .offset(
                x: isFlyingAway && !reduceMotion ? 1000 : 0,
                y: isFlyingAway && !reduceMotion ? -700 : 0
            )
            .animation(.easeIn(duration: 0.5), value: phase)
    }

    private var isFlyingAway: Bool { phase >= .flyAway }

    private func pose(for piece: SquabLogoPiece) -> SquabLogoPiecePose {
        if reduceMotion {
            return SquabLogoPiecePose(opacity: phase >= .assembled ? 1 : 0)
        }
        switch piece {
        case .tailLower:
            return phase >= .assembled
                ? .identity
                : SquabLogoPiecePose(offset: CGSize(width: -0.1, height: 1.2), rotation: .degrees(60))
        case .tailUpper:
            return phase >= .assembled
                ? .identity
                : SquabLogoPiecePose(offset: CGSize(width: -1.2, height: 0.3), rotation: .degrees(-90))
        case .wing:
            if isFlyingAway {
                return SquabLogoPiecePose(rotation: .degrees(-35), anchor: Self.wingJoint)
            }
            return phase >= .assembled
                ? .identity
                : SquabLogoPiecePose(offset: CGSize(width: -1.4, height: -0.2), rotation: .degrees(35))
        case .body:
            switch phase {
            case .curtain:
                return SquabLogoPiecePose(offset: CGSize(width: 0.15, height: -1.4), rotation: .degrees(-30))
            case .squawk:
                return SquabLogoPiecePose(
                    offset: CGSize(width: 0.01, height: -0.05),
                    rotation: .degrees(-5),
                    anchor: UnitPoint(x: 0.55, y: 0.85)
                )
            default:
                return .identity
            }
        case .receipt, .receiptCurl:
            return phase >= .unfurled
                ? .identity
                : SquabLogoPiecePose(rotation: .degrees(-70), anchor: Self.beakTip, scale: 0.01, opacity: 0)
        }
    }

    private func animation(for piece: SquabLogoPiece) -> Animation? {
        if reduceMotion {
            return .easeInOut(duration: 0.3)
        }
        switch (piece, phase) {
        case (.wing, _) where isFlyingAway:
            return .easeInOut(duration: 0.1).repeatForever(autoreverses: true)
        case (_, .assembled):
            return .spring(duration: 0.5, bounce: 0.38).delay(Self.arrivalDelay(for: piece))
        case (.body, .squawk), (.body, .unfurled):
            return .spring(duration: 0.3, bounce: 0.6)
        case (.receipt, .unfurled):
            return .spring(duration: 0.5, bounce: 0.5)
        case (.receiptCurl, .unfurled):
            return .spring(duration: 0.45, bounce: 0.55).delay(0.12)
        default:
            return .default
        }
    }

    private static func arrivalDelay(for piece: SquabLogoPiece) -> TimeInterval {
        switch piece {
        case .tailLower: 0
        case .tailUpper: 0.06
        case .wing: 0.12
        case .body: 0.2
        case .receipt, .receiptCurl: 0
        }
    }

    private static let wingJoint = SquabLogoPieceShape.anchor(for: SquabLogoPiece.wingJoint)
    private static let beakTip = SquabLogoPieceShape.anchor(for: SquabLogoPiece.beakTip)

    // MARK: - Playback

    @Sendable
    private func play() async {
        let start = ContinuousClock.now
        for step in LaunchPhase.script {
            try? await Task.sleep(until: start + step.at, clock: .continuous)
            guard !Task.isCancelled, !skipped else { return }
            phase = step.phase
            if let sound = step.phase.sound {
                sounds.play(sound)
            }
        }
        try? await Task.sleep(for: LaunchPhase.fadeOut)
        guard !Task.isCancelled, !skipped else { return }
        onFinished()
    }

    private func skip() {
        guard !skipped, phase < .done else { return }
        skipped = true
        phase = .done
        sounds.stop()
        Task {
            try? await Task.sleep(for: LaunchPhase.fadeOut)
            onFinished()
        }
    }
}

#Preview {
    LaunchSplashView {}
}
