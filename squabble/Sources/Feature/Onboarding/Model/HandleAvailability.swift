/// What the handle field says under itself while the user types. Only a handle the
/// server has confirmed as free lets the user continue — the first step is where the
/// handle gets settled, not the final save.
nonisolated enum HandleAvailability: Equatable {
    case idle
    case checking
    case available
    case taken
    case offline
    /// The server couldn't be asked for some other reason; worth a retry.
    case failed
    case invalid(HandleError)

    var allowsContinuing: Bool {
        self == .available
    }
}
