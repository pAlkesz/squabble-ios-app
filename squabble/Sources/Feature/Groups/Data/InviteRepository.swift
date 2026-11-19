import Foundation

/// Invites go through Cloud Functions (`createInvite`, `resetInvite`, `previewInvite`,
/// `joinGroup`): a non-member can't read or write the squabble, and the code is minted on
/// the server. All of them need a connection.
protocol InviteRepository: Sendable {
    /// The squabble's code, created the first time a member asks.
    func inviteCode(for groupID: String) async throws(InviteError) -> String
    /// Creator only: kills the current link and returns the new code.
    func resetInvite(for groupID: String) async throws(InviteError) -> String
    func preview(code: String) async throws(InviteError) -> InvitePreview
    /// Returns the squabble's id. Joining a squabble you're already in is fine.
    func join(code: String) async throws(InviteError) -> String
}
