nonisolated protocol AuthService: Sendable {
    var currentUser: AppUser? { get }

    /// Emits the current user immediately, then on every change, until cancelled.
    func authStateChanges() -> AsyncStream<AppUser?>

    func signIn(with apple: AppleSignInResult) async throws

    func signOut() throws

    /// Apple requires a fresh authorization to delete: Firebase re-authenticates with it
    /// and revokes the Apple token before removing the user.
    func deleteAccount(reauthenticatingWith apple: AppleSignInResult) async throws
}
