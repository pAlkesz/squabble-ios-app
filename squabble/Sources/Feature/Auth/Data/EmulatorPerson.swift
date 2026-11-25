#if DEBUG && targetEnvironment(simulator)
import FirebaseAuth
import Foundation

/// The fake people `emulator/seed.mjs` puts in the local emulator.
nonisolated enum EmulatorPerson: String, CaseIterable, Identifiable {
    case anna, bela, cili, dora

    var id: String { rawValue }

    /// Local emulator only; opens nothing anywhere else.
    private static let password = "squabble-local"

    func signIn() async throws {
        _ = try await Auth.auth().signIn(withEmail: "\(rawValue)@example.com", password: Self.password)
    }

    /// A fresh account without a profile, for onboarding.
    static func signInAsSomeoneNew() async throws {
        _ = try await Auth.auth().createUser(withEmail: "\(UUID().uuidString)@example.com", password: password)
    }
}
#endif
