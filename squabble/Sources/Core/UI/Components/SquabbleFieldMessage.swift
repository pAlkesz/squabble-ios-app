/// The line under a `SquabbleField`.
struct SquabbleFieldMessage: Equatable {
    enum Tone {
        case hint
        case success
        case problem
    }

    let text: String
    let tone: Tone
}
