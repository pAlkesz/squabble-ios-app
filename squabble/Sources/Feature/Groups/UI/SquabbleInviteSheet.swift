import FactoryKit
import SwiftUI

/// The squabble's invite link as a QR code with a share button, like Revolut's. The code is
/// minted by the server the first time; after that it's on the group, so the sheet works
/// offline. The creator can reset it.
struct SquabbleInviteSheet: View {
    let groupID: String

    @Injected(\.inviteRepository) private var invites
    @Environment(GroupsStore.self) private var groups
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var fetchedCode: String?
    @State private var failure: InviteError?
    @State private var isConfirmingReset = false
    @State private var isResetting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let group = groups.group(id: groupID) {
                    card(group)
                        .padding(16)
                        .frame(maxWidth: 480)
                        .frame(maxWidth: .infinity)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .foregroundStyle(.white)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .task { await loadCode() }
    }

    private var code: String? {
        fetchedCode ?? groups.group(id: groupID)?.inviteCode
    }

    private func card(_ group: SquabbleGroup) -> some View {
        VStack(spacing: 20) {
            qrCode(group)
                .frame(height: 240)
                .padding(.top, 12)
            VStack(spacing: 8) {
                Text(verbatim: group.name)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(explanation(group))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            if let code, let url = InviteLink.url(code: code) {
                ShareLink(item: url) {
                    Label {
                        Text("Share link", comment: "Invite sheet: button that opens the share sheet with the invite link.")
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .font(.headline)
                    .foregroundStyle(Color.backdropDeep)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 50)
                    .background(.white, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            if group.createdBy == session.user?.id, code != nil {
                Button {
                    isConfirmingReset = true
                } label: {
                    if isResetting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Reset link", comment: "Invite sheet: creator-only button that replaces the invite link.")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isResetting)
                .confirmationDialog(
                    Text("Reset the invite link?", comment: "Invite sheet: title of the reset confirmation."),
                    isPresented: $isConfirmingReset,
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive) {
                        Task { await reset() }
                    } label: {
                        Text("Reset link", comment: "Invite sheet: creator-only button that replaces the invite link.")
                    }
                } message: {
                    Text("The old link and QR code stop working. People already in stay in.", comment: "Invite sheet: message of the reset confirmation.")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
    }

    @ViewBuilder
    private func qrCode(_ group: SquabbleGroup) -> some View {
        if let code, let url = InviteLink.url(code: code), let matrix = QRMatrix(url.absoluteString) {
            InviteQRCode(matrix: matrix, image: group.image)
        } else if let failure {
            VStack(spacing: 12) {
                Text(verbatim: failure.localizedDescription)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await loadCode() }
                } label: {
                    Text("Try again", comment: "Invite sheet: retry after the link couldn't be made.")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        } else {
            ProgressView().tint(.white)
        }
    }

    private func explanation(_ group: SquabbleGroup) -> String {
        if group.createdBy == session.user?.id {
            return String(localized: "Anyone with this link or QR code can join. They'll need the app, no freeloaders. It works until you reset it.", comment: "Invite sheet: explanation shown to the creator.")
        }
        return String(localized: "Anyone with this link or QR code can join. They'll need the app, no freeloaders.", comment: "Invite sheet: explanation shown to other members.")
    }

    private func loadCode() async {
        guard code == nil else { return }
        failure = nil
        do {
            fetchedCode = try await invites.inviteCode(for: groupID)
        } catch {
            failure = error
        }
    }

    private func reset() async {
        isResetting = true
        defer { isResetting = false }
        do {
            fetchedCode = try await invites.resetInvite(for: groupID)
        } catch {
            failure = error
        }
    }
}
