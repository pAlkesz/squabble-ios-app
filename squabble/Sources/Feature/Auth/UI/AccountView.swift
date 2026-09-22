import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false
    @State private var isReauthenticating = false
    @State private var isDeleting = false
    @State private var failure: AccountFailure?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let profile = session.profile {
                        HStack(spacing: 14) {
                            AvatarView(profile.avatar, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: profile.displayName)
                                    .font(.headline)
                                Text(verbatim: profile.handle.description)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Section {
                    Button("Sign out", action: signOut)
                    Button("Delete account", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete your account?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Continue", role: .destructive) { isReauthenticating = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This wipes your account and everything in it. Your friends will still owe you money — that part's between you and them.")
            }
            .sheet(isPresented: $isReauthenticating) {
                reauthenticationSheet
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }),
                presenting: failure
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { failure in
                Text(failure.message)
            }
        }
    }

    private var reauthenticationSheet: some View {
        VStack(spacing: 24) {
            Text("Confirm with Apple to delete your account.")
                .font(.headline)
                .multilineTextAlignment(.center)
            AppleSignInButton(label: .continue, onCompletion: deleteAccount)
                .disabled(isDeleting)
        }
        .padding(24)
        .presentationDetents([.fraction(0.3)])
    }

    private func signOut() {
        do {
            try session.signOut()
        } catch {
            failure = AccountFailure(message: error.localizedDescription)
        }
    }

    private func deleteAccount(_ result: Result<AppleSignInResult, Error>) {
        Task {
            isDeleting = true
            defer { isDeleting = false }
            do {
                try await session.deleteAccount(confirmingWith: result.get())
                isReauthenticating = false
            } catch {
                isReauthenticating = false
                failure = AccountFailure(message: error.localizedDescription)
            }
        }
    }
}

private struct AccountFailure: Identifiable {
    let id = UUID()
    let message: String
}
