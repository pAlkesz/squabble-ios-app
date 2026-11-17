nonisolated protocol AuthService: Sendable {
    var currentUser: AppUser? { get }

    /// Emits the current user immediately, then on every change, until cancelled.
    func authStateChanges() -> AsyncStream<AppUser?>

    func signIn(with apple: AppleSignInResult) async throws

    func signOut() throws

    /// Apple requires a fresh authorization to delete. Re-authenticating first proves it's
    /// really the user and gives a fresh token for wiping their data before the account goes.
    func reauthenticate(with apple: AppleSignInResult) async throws

    /// Revokes Squabble's Sign in with Apple access, which App Review requires on deletion.
    /// Needs the Apple provider's Services ID and key set up in the Firebase console.
    func revokeAppleAccess(_ apple: AppleSignInResult) async throws

    /// Removes the auth user, which signs them out. Call last: deleting their data needs them
    /// signed in.
    func deleteUser() async throws
}
