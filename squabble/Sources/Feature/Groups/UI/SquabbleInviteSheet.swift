import FactoryKit
import SwiftUI

/// The squabble's invite link as a QR code with a share button. The code is minted by the
/// server the first time; after that it's on the group, so the sheet works offline.
struct SquabbleInviteSheet: View {
    let groupID: String

    @Injected(\.inviteRepository) private var invites
    @Environment(GroupsStore.self) private var groups
    @Environment(\.dismiss) private var dismiss
    @State private var fetchedCode: String?
    @State private var failure: InviteError?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let group = groups.group(id: groupID) {
                    content(group)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: 480)
                        .frame(maxWidth: .infinity)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) { shareButton }
        }
        .foregroundStyle(.white)
        .presentationDetents([.fraction(0.72)])
        .presentationBackground { ProfileBackdrop() }
        .task { await loadCode() }
    }

    private var url: URL? {
        (groups.group(id: groupID)?.inviteCode ?? fetchedCode).flatMap(InviteLink.url(code:))
    }

    private func content(_ group: SquabbleGroup) -> some View {
        VStack(spacing: 28) {
            qrCode(group)
                .frame(height: 250)
            VStack(spacing: 8) {
                Text(verbatim: group.name)
                    .font(.title.bold())
                Text("Anyone with this link or QR code can join. They'll need the app, no freeloaders.", comment: "Invite sheet: what the link does.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let url {
            ShareLink(item: url) {
                Label {
                    Text("Share link", comment: "Invite sheet: button that opens the share sheet with the invite link.")
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .buttonStyle(.squabblePrimary)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: 560)
        }
    }

    @ViewBuilder
    private func qrCode(_ group: SquabbleGroup) -> some View {
        if let url, let matrix = QRMatrix(url.absoluteString) {
            InviteQRCode(matrix: matrix, image: group.image, size: 250)
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

    private func loadCode() async {
        guard url == nil else { return }
        failure = nil
        do {
            fetchedCode = try await invites.inviteCode(for: groupID)
        } catch {
            failure = error
        }
    }
}
