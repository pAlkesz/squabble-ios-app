import Foundation

/// An invite code the app was opened with, waiting until there's a signed-in user with a
/// profile to show it to.
nonisolated struct PendingInvite: Identifiable, Equatable, Sendable {
    let code: String
    var id: String { code }
}
