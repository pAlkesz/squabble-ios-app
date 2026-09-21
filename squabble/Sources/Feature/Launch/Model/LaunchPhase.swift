/// The beats of the launch animation, in order. `script` says when each one starts,
/// measured from the moment the splash appears.
nonisolated enum LaunchPhase: Int, Comparable, Sendable {
    /// Plain green field, identical to the static launch screen.
    case curtain
    /// Paper pieces fly in and snap together.
    case assembled
    /// The bird hops, pleased with itself.
    case squawk
    /// The receipt unrolls from the beak.
    case unfurled
    /// Bird takes the receipt and leaves; the field fades to reveal the app.
    case flyAway
    /// Fully faded; the splash can be removed.
    case done

    static let script: [(phase: LaunchPhase, at: Duration)] = [
        (.assembled, .zero),
        (.squawk, .milliseconds(650)),
        (.unfurled, .milliseconds(780)),
        (.flyAway, .milliseconds(1350)),
        (.done, .milliseconds(1750)),
    ]

    /// The effect that starts with this phase, if any.
    var sound: LaunchSound? {
        switch self {
        case .squawk: .squawk
        case .flyAway: .flyaway
        default: nil
        }
    }

    /// Time the outro fade needs after `.done` before the view is torn down.
    static let fadeOut: Duration = .milliseconds(300)

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
