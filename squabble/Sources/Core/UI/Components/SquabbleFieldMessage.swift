import SwiftUI

/// A form section footer that can also report a problem: hints stay in the system's
/// footer style, success and problems get their own colour.
struct SquabbleFieldMessage: Equatable {
    enum Tone {
        case hint
        case success
        case problem
    }

    let text: String
    let tone: Tone

    var color: Color? {
        switch tone {
        case .hint: nil
        case .success: .white
        case .problem: .red
        }
    }
}
