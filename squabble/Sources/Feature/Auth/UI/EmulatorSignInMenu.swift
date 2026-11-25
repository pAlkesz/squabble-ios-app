#if DEBUG
import SwiftUI

/// Developer-only, so not localized: switches between live and the local emulator, and signs
/// in as a fake person on the latter.
struct EmulatorSignInMenu: View {
    @State private var failure: String?
    @State private var isAskingForHost = false
    @State private var host = LocalEmulator.host ?? ""

    var body: some View {
        Menu {
            if LocalEmulator.isEnabled {
                Section {
                    ForEach(EmulatorPerson.allCases) { person in
                        Button { signIn(person.signIn) } label: { Text(verbatim: "Sign in as \(person.rawValue.capitalized)") }
                    }
                    Button { signIn(EmulatorPerson.signInAsSomeoneNew) } label: { Text(verbatim: "Sign in as someone new") }
                }
                #if !targetEnvironment(simulator)
                Button { isAskingForHost = true } label: { Text(verbatim: "Mac's address: \(LocalEmulator.host ?? "")") }
                #endif
                Button { LocalEmulator.setEnabled(false) } label: { Text(verbatim: "Use live (quits the app)") }
            } else {
                Button { useLocal() } label: { Text(verbatim: "Use local emulator (quits the app)") }
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
        .alert(Text(verbatim: "Your Mac's address"), isPresented: $isAskingForHost) {
            TextField(text: $host) { Text(verbatim: "192.168.0.10") }
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                guard let host = LocalEmulator.validHost(host) else { return }
                LocalEmulator.setHost(host)
                LocalEmulator.setEnabled(true)
            } label: { Text(verbatim: "Save (quits the app)") }
            .disabled(LocalEmulator.validHost(host) == nil)
            Button(role: .cancel) {} label: { Text(verbatim: "Cancel") }
        } message: {
            Text(verbatim: "Printed by emulator/start.sh --wifi. Both must be on the same Wi-Fi.")
        }
        .alert(Text(verbatim: "Local sign-in failed"), isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button(role: .cancel) {} label: { Text(verbatim: "OK") }
        } message: {
            Text(verbatim: failure ?? "")
        }
    }

    private func useLocal() {
        #if targetEnvironment(simulator)
        LocalEmulator.setEnabled(true)
        #else
        isAskingForHost = true
        #endif
    }

    private func signIn(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                failure = "\(error.localizedDescription)\n\nIs emulator/start.sh running (with --wifi for a phone), and is Local Network allowed in Settings?"
            }
        }
    }
}
#endif
