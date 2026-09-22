nonisolated protocol AuthService: Sendable {
    var currentUser: AppUser? { get }

    /// Emits the current user immediately, then on every change, until cancelled.
    func authStateChanges() -> AsyncStream<AppUser?>

    func signIn(with apple: AppleSignInResult) async throws

    func signOut() throws

    /// Apple requires a fresh authorization to delete. Re-authenticating first proves it's
    /// really the user and gives a fresh token for wiping their data before the account goes.
    func reauthenticate(with apple: AppleSignInResult) async throws

    /// Revokes the Apple token, then removes the user. Call after `reauthenticate(with:)`.
    func deleteAccount(revoking apple: AppleSignInResult) async throws
}
