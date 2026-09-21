import Testing
@testable import squabble

struct AppleSignInNonceTests {
    @Test func randomNonceHasRequestedLengthAndSafeCharacters() {
        let nonce = AppleSignInNonce.random(length: 32)
        #expect(nonce.count == 32)
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        #expect(nonce.allSatisfy(allowed.contains))
    }

    @Test func randomNoncesDiffer() {
        #expect(AppleSignInNonce.random() != AppleSignInNonce.random())
    }

    @Test func sha256MatchesKnownDigest() {
        #expect(AppleSignInNonce.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
