/// The beats of the launch animation, in order. `script` says when each intro beat
/// starts, measured from the moment the splash appears; the exit waits for the app.
nonisolated enum LaunchPhase: Int, Comparable, Sendable {
    /// Plain green field, identical to the static launch screen.
    case curtain
    /// Paper pieces fly in and snap together.
    case assembled
    /// The bird hops, pleased with itself.
    case squawk
    /// The receipt unrolls from the beak. The bird holds this pose until the app
    /// knows which screen to show.
    case unfurled
    /// Bird takes the receipt and leaves; the field fades to reveal the app.
    case flyAway
    /// Fully faded; the splash can be removed.
    case done

    static let script: [(phase: LaunchPhase, at: Duration)] = [
        (.assembled, .zero),
        (.squawk, .milliseconds(650)),
        (.unfurled, .milliseconds(780)),
    ]

    /// When the unfurl has settled and the bird stands still — the cheapest moment to
    /// build the first real screen underneath. The receipt's bouncy springs wobble on
    /// until about here; mounting any earlier freezes the tail of that wobble.
    static let hold: Duration = .milliseconds(1550)

    /// Grace after the screen underneath is mounted, so its first frame has committed
    /// before anything starts moving again.
    static let settle: Duration = .milliseconds(50)

    /// How long the bird takes to leave before the fade starts.
    static let flight: Duration = .milliseconds(400)

    /// Time the outro fade needs after `.done` before the view is torn down.
    static let fadeOut: Duration = .milliseconds(300)

    /// How long the bird stands still between fidgets while it waits.
    static let fidgetInterval: Duration = .milliseconds(1600)

    /// The effect that starts with this phase, if any.
    var sound: LaunchSound? {
        switch self {
        case .assembled: .arrival
        case .squawk: .hop
        case .flyAway: .flyaway
        default: nil
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
