import AuthenticationServices
import PhotosUI
import SwiftUI

/// The profile and account screen, pushed from the home avatar like any other page, so the
/// photo picker and payment editor open as a single sheet instead of one on top of another.
/// Its editing pages (`AccountPage`) are pushed on the same stack; home registers them and
/// gives every page its backdrop. Tapping the avatar opens a menu: after onboarding the only
/// avatar change is to upload a photo or remove it.
struct AccountView: View {
    @Environment(AuthSession.self) private var session
    @Environment(PreferencesStore.self) private var preferences
    @State private var isShowingLibrary = false
    @State private var isShowingCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUpdatingAvatar = false
    @State private var isConfirmingDelete = false
    @State private var isReauthenticating = false
    @State private var isDeleting = false
    @State private var failure: AccountFailure?

    var body: some View {
        root
            .navigationBarTitleDisplayMode(.inline)
            .foregroundStyle(.white)
        .confirmationDialog("Delete your account?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Continue", role: .destructive) { isReauthenticating = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This wipes your account and everything in it. Your friends will still owe you money — that part's between you and them.")
        }
        .photosPicker(isPresented: $isShowingLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPicked(item) }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { jpeg in
                isShowingCamera = false
                guard let jpeg else { return }
                Task { await setPhoto(jpeg) }
            }
            .ignoresSafeArea()
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
                    settings(for: profile)
                }
                accountActions
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private func header(for profile: UserProfile) -> some View {
        VStack(spacing: 10) {
            avatarMenu(for: profile)
            VStack(spacing: 2) {
                Text(verbatim: profile.displayName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(verbatim: profile.handle.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Known associates: everyone you owe.", comment: "Account screen: joke caption under the handle, on the mugshot height chart.")
                    .font(.footnote.italic())
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background {
            // Full width and up under the navigation bar, fading out below the caption.
            LineupChart()
                .padding(.horizontal, -16)
                .padding(.top, -60)
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0.6), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                }
        }
    }

    private func avatarMenu(for profile: UserProfile) -> some View {
        Menu {
            Button("Choose from library", systemImage: "photo.on.rectangle") {
                isShowingLibrary = true
            }
            if CameraPicker.isAvailable {
                Button("Take a photo", systemImage: "camera") {
                    isShowingCamera = true
                }
            }
            if profile.avatar.photoPath != nil {
                Button("Remove photo", systemImage: "trash", role: .destructive) {
                    ProfileEditor().removePhoto(from: profile)
                }
            }
        } label: {
            AvatarView(profile.avatar, size: 96)
                .overlay {
                    if isUpdatingAvatar {
                        Circle().fill(.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .glassEffect(.regular, in: .circle)
                }
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingAvatar)
        .accessibilityLabel(Text("Change photo", comment: "Account screen: accessibility label of the avatar menu."))
    }

    // MARK: - Rows

    private func settings(for profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            link("Display name", systemImage: "person.text.rectangle", to: .displayName) {
                Text(verbatim: profile.displayName)
            }
            divider
            link("Payment details", systemImage: "banknote", to: .paymentDetails)
            divider
            link("Default currency", systemImage: "dollarsign.arrow.circlepath", to: .homeCurrency) {
                Text(verbatim: preferences.homeCurrencyCode)
            }
        }
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
    }

    private var accountActions: some View {
        VStack(spacing: 0) {
            row("Sign out", systemImage: "rectangle.portrait.and.arrow.right", action: signOut)
            divider
            row("Delete account", systemImage: "trash", role: .destructive) {
                isConfirmingDelete = true
            }
        }
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
    }

    private var divider: some View {
        Divider()
            .overlay(.white.opacity(0.12))
            .padding(.leading, 52)
    }

    private func link(
        _ title: LocalizedStringKey,
        systemImage: String,
        to page: AccountPage,
        @ViewBuilder value: () -> some View = { EmptyView() }
    ) -> some View {
        NavigationLink(value: page) {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .labelStyle(AccountRowLabelStyle())
                    .layoutPriority(1)
                Spacer(minLength: 0)
                value()
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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

    // MARK: - Avatar

    private func loadPicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw ProfileError.invalidImage }
            await setPhoto(data)
        } catch {
            failure = AccountFailure(message: error.localizedDescription)
        }
    }

    private func setPhoto(_ data: Data) async {
        guard let profile = session.profile else { return }
        isUpdatingAvatar = true
        defer { isUpdatingAvatar = false }
        // Shrinks and crops off the main thread; a camera or library original can be huge.
        let jpeg = await Task.detached(priority: .userInitiated) {
            AvatarImageProcessor.squareJPEG(from: data)
        }.value
        do {
            guard let jpeg else { throw ProfileError.invalidImage }
            try await ProfileEditor().setPhoto(jpeg, on: profile)
        } catch {
            AppLog.error(error, "Avatar photo change failed")
            failure = AccountFailure(message: error.localizedDescription)
        }
    }

    // MARK: - Account

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
