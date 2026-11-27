import SwiftUI

/// A short confirmation that floats in on glass and goes away by itself, shown with
/// `.squabbleToast(_:)`. A new one replaces the one on screen and restarts the clock.
struct SquabbleToast: Identifiable, Equatable {
    let id = UUID()
    let title: LocalizedStringResource
    let systemImage: String

    static var copied: SquabbleToast {
        SquabbleToast(
            title: LocalizedStringResource("Copied to clipboard", comment: "Toast shown after copying a message's text."),
            systemImage: "doc.on.doc.fill"
        )
    }

    static var reported: SquabbleToast {
        SquabbleToast(
            title: LocalizedStringResource("Reported. We'll take it from here.", comment: "Toast shown after reporting a message."),
            systemImage: "flag.fill"
        )
    }
}
