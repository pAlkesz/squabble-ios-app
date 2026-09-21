import AuthenticationServices

/// What Firebase needs from a completed Sign in with Apple authorization.
nonisolated struct AppleSignInResult: Sendable {
    let identityToken: String
    let authorizationCode: String
    let rawNonce: String
    let fullName: PersonNameComponents?

    init(authorization: ASAuthorization, rawNonce: String) throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8)
        else { throw AuthError.missingIdentityToken }
        guard let codeData = credential.authorizationCode,
              let authorizationCode = String(data: codeData, encoding: .utf8)
        else { throw AuthError.missingAuthorizationCode }

        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.rawNonce = rawNonce
        self.fullName = credential.fullName
    }

    init(identityToken: String, authorizationCode: String, rawNonce: String, fullName: PersonNameComponents?) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.rawNonce = rawNonce
        self.fullName = fullName
    }
}
