import AuthenticationServices
import SwiftUI

/// The profile and account screen, a sheet from the home avatar. It has no background of its
/// own; the sheet provides it. Its `NavigationStack` is for account pages yet to come.
struct AccountView: View {
    let onClose: () -> Void

    @Environment(AuthSession.self) private var session
    @State private var isConfirmingDelete = false
    @State private var isReauthenticating = false
    @State private var isDeleting = false
    @State private var failure: AccountFailure?

    var body: some View {
        // Pages pushed here later need a clear container background too, to share the sheet's.
        NavigationStack {
            root
                // The × is a real toolbar item, not part of the page, so pushing and popping
                // morph it into the back button in place instead of sliding it with the page.
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        // A styled label: toolbar buttons ignore `.tint`.
                        Button(action: onClose) {
                            Image(systemName: "xmark").foregroundStyle(.white)
                        }
                        .accessibilityLabel("Close")
                    }
                }
                .containerBackground(.clear, for: .navigation)
        }
        // The system back button follows the stack's tint.
        .tint(.white)
        .foregroundStyle(.white)
        .accessibilityAction(.escape, onClose)
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

    private var root: some View {
        ScrollView {
            VStack(spacing: 28) {
                if let profile = session.profile {
                    header(for: profile)
                }
                actions
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private func header(for profile: UserProfile) -> some View {
        VStack(spacing: 10) {
            AvatarView(profile.avatar, size: 96)
            VStack(spacing: 2) {
                Text(verbatim: profile.displayName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(verbatim: profile.handle.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            row("Sign out", systemImage: "rectangle.portrait.and.arrow.right", action: signOut)
            Divider()
                .overlay(.white.opacity(0.12))
                .padding(.leading, 52)
            row("Delete account", systemImage: "trash", role: .destructive) {
                isConfirmingDelete = true
            }
        }
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
    }

    private func row(
        _ title: LocalizedStringKey,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(AccountRowLabelStyle())
                .foregroundStyle(role == .destructive ? Color.red : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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

private struct AccountRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            configuration.icon
                .font(.body.weight(.medium))
                .frame(width: 22)
            configuration.title
        }
    }
}

private struct AccountFailure: Identifiable {
    let id = UUID()
    let message: String
}
