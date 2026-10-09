import SwiftUI

/// The animated hand-off from the static launch screen: it starts as the same plain
/// green field, assembles the bird out of paper pieces, then the bird flies off with
/// the receipt and the field fades to reveal the app. If the app hasn't decided which
/// screen to show by then, the bird waits — fidgeting now and then — until it has.
/// While it waits a spinner sits below it, unless an error is up instead (`hasError`).
/// Tapping skips to the finished bird, then fades as soon as the app is ready.
/// Reduce Motion replaces the choreography with a plain cross-fade.
struct LaunchSplashView: View {
    let isContentReady: Bool
    var hasError = false
    let onReadyForContent: @MainActor () -> Void
    let onFinished: @MainActor () -> Void
    // State, not a plain property: SwiftUI rebuilds this struct whenever its inputs
    // change, and a fresh player would have none of the prepared sounds loaded.
    @State private var sounds: any LaunchSoundPlaying = LaunchSoundPlayer()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = LaunchPhase.curtain
    @State private var skipped = false
    /// The intro is over and the bird is waiting on the app.
    @State private var isHolding = false
    @State private var isFidgeting = false
    @State private var departure: Task<Void, Never>?

    var body: some View {
        ZStack {
            // The asset colour, not `Color.accentColor`: the error sheet can come up over
            // the splash, and iOS greys out (and thins) the tint behind a sheet.
            Color.accent
            logo
                .padding(.horizontal, 32)
            spinner
        }
        .ignoresSafeArea()
        .opacity(phase == .done ? 0 : 1)
        .animation(.easeOut(duration: 0.3), value: phase)
        .contentShape(Rectangle())
        .onTapGesture(perform: skip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Squabble", comment: "App name, read by VoiceOver on the launch splash."))
        .accessibilityAddTraits(.isImage)
        .accessibilityValue(isLoading ? Text("Loading…", comment: "VoiceOver: the launch splash is waiting for the app to load.") : Text(verbatim: ""))
        .accessibilityAction(named: Text("Skip intro", comment: "VoiceOver action to skip the launch animation."), skip)
        .task(play)
        .task(id: isWaiting, fidget)
        .onChange(of: isContentReady) { leaveIfReady() }
    }

    // MARK: - Spinner

    /// Centred in the space under the bird: an invisible copy of the logo takes the
    /// bird's slot so the two flexible spacers split the rest evenly, as the ZStack does.
    private var spinner: some View {
        VStack(spacing: 0) {
            Color.clear
            SquabLogoView()
                .frame(maxWidth: 320)
                .padding(.horizontal, 32)
                .hidden()
            ProgressView()
                .controlSize(.large)
                .tint(.white)
                .frame(maxHeight: .infinity)
                .opacity(isLoading ? 1 : 0)
                // Fast answers never show it; slow ones fade it in after a beat.
                .animation(isLoading ? .easeIn(duration: 0.25).delay(0.3) : .easeOut(duration: 0.15), value: isLoading)
        }
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
                return Self.hopPose
            case .unfurled where isFidgeting:
                return Self.hopPose
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

    /// The body's little hop: on the squawk, and again whenever the waiting bird fidgets.
    private static let hopPose = SquabLogoPiecePose(
        offset: CGSize(width: 0.01, height: -0.05),
        rotation: .degrees(-5),
        anchor: UnitPoint(x: 0.55, y: 0.85)
    )

    private static let wingJoint = SquabLogoPieceShape.anchor(for: SquabLogoPiece.wingJoint)
    private static let beakTip = SquabLogoPieceShape.anchor(for: SquabLogoPiece.beakTip)

    // MARK: - Playback

    /// The intro is over and the app is still working out which screen to show.
    private var isLoading: Bool { isHolding && !isContentReady && !hasError }

    private var isWaiting: Bool { isLoading && !reduceMotion }

    @Sendable
    private func play() async {
        // Nothing moves until the first beat, so the warm-up isn't visible.
        await sounds.prepare()
        let start = ContinuousClock.now
        for step in LaunchPhase.script {
            try? await Task.sleep(until: start + step.at, clock: .continuous)
            guard !Task.isCancelled, !skipped else { return }
            phase = step.phase
            if let sound = step.phase.sound {
                await sounds.play(sound)
            }
        }
        try? await Task.sleep(until: start + LaunchPhase.hold, clock: .continuous)
        guard !Task.isCancelled, !skipped else { return }
        hold()
    }

    private func hold() {
        isHolding = true
        onReadyForContent()
        leaveIfReady()
    }

    private func leaveIfReady() {
        guard isHolding, isContentReady, departure == nil else { return }
        departure = Task {
            try? await Task.sleep(for: LaunchPhase.settle)
            if !skipped {
                phase = .flyAway
                if let sound = phase.sound {
                    await sounds.play(sound)
                }
                try? await Task.sleep(for: LaunchPhase.flight)
            }
            phase = .done
            try? await Task.sleep(for: LaunchPhase.fadeOut)
            onFinished()
        }
    }

    private func skip() {
        guard !skipped, phase < .flyAway else { return }
        skipped = true
        Task { await sounds.stop() }
        if !isHolding {
            phase = .unfurled
            hold()
        }
    }

    /// A little hop every so often, so a slow answer doesn't look like a frozen app.
    @Sendable
    private func fidget() async {
        defer { isFidgeting = false }
        guard isWaiting else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: LaunchPhase.fidgetInterval)
            guard !Task.isCancelled else { return }
            isFidgeting = true
            try? await Task.sleep(for: .milliseconds(250))
            isFidgeting = false
        }
    }
}

#Preview {
    LaunchSplashView(isContentReady: false, onReadyForContent: {}, onFinished: {})
}
