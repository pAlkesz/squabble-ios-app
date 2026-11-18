import SwiftUI

/// How home's toolbar avatar and the membership welcome meet: home reports where its avatar
/// sits on screen, and keeps it hidden while the welcome is up, so the card's photo can fly
/// onto that exact spot and hand over without a visible swap.
struct AvatarFrameReporter {
    let report: (CGRect) -> Void

    func callAsFunction(_ frame: CGRect) {
        report(frame)
    }
}

extension EnvironmentValues {
    @Entry var reportAvatarFrame = AvatarFrameReporter { _ in }
    @Entry var isMembershipWelcomeShowing = false
}
