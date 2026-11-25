#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// Developer-only, so not localized: switches between live and the local emulator, and signs
/// in as a fake person on the latter.
struct EmulatorSignInMenu: View {
    @State private var failure: String?

    var body: some View {
        Menu {
            if LocalEmulator.isEnabled {
                Section {
                    ForEach(EmulatorPerson.allCases) { person in
                        Button { signIn(person.signIn) } label: { Text(verbatim: "Sign in as \(person.rawValue.capitalized)") }
                    }
                    Button { signIn(EmulatorPerson.signInAsSomeoneNew) } label: { Text(verbatim: "Sign in as someone new") }
                }
                Button { LocalEmulator.setEnabled(false) } label: { Text(verbatim: "Use live (quits the app)") }
            } else {
                Button { LocalEmulator.setEnabled(true) } label: { Text(verbatim: "Use local emulator (quits the app)") }
            }
        } label: {
            Text(verbatim: LocalEmulator.isEnabled ? "LOCAL" : "LIVE")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black.opacity(0.35), in: .capsule)
        }
        .padding(.trailing, 16)
        .alert(Text(verbatim: "Local sign-in failed"), isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button(role: .cancel) {} label: { Text(verbatim: "OK") }
        } message: {
            Text(verbatim: failure ?? "")
        }
    }

    private func signIn(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                failure = "\(error.localizedDescription)\n\nIs emulator/start.sh running?"
            }
        }
    }
}
#endif
