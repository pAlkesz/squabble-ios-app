import Foundation
import Observation

/// Holds the invite link the app was opened with. Owned by the root, so a link opened
/// before signing in survives onboarding; home shows it once it's mounted.
@Observable
final class InviteInbox {
    var pending: PendingInvite?

    /// Returns whether the URL was an invite link.
    @discardableResult
    func receive(_ url: URL) -> Bool {
        guard let code = InviteLink.code(from: url) else { return false }
        pending = PendingInvite(code: code)
        return true
    }
}
