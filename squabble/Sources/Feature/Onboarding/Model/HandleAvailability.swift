/// What the handle field says under itself while the user types.
nonisolated enum HandleAvailability: Equatable {
    case idle
    case checking
    case available
    case taken
    /// Couldn't ask (offline); the save will settle it.
    case unknown
    case invalid(HandleError)

    var blocksContinuing: Bool {
        switch self {
        case .taken, .invalid: true
        case .idle, .checking, .available, .unknown: false
        }
    }
}
