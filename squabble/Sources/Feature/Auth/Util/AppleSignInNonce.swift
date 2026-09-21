import CryptoKit
import Foundation

/// Sign in with Apple replay protection: the raw nonce goes to Firebase, its SHA-256 goes to Apple.
nonisolated enum AppleSignInNonce {
    private static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    static func random(length: Int = 32) -> String {
        String((0..<length).map { _ in
            alphabet[Int.random(in: 0..<alphabet.count)]
        })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
