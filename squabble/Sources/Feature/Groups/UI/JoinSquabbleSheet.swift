import FactoryKit
import SwiftUI

/// Opened by an invite link: the squabble's name, picture and size from the server, and a
/// button to join. Nothing is joined without the tap.
struct JoinSquabbleSheet: View {
    let invite: PendingInvite
    let onJoined: (String) -> Void

    @Injected(\.inviteRepository) private var invites
    @Environment(GroupsStore.self) private var groups
    @Environment(\.dismiss) private var dismiss
    @State private var preview: InvitePreview?
    @State private var failure: InviteError?
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) { button }
        }
        .task { await load() }
        .interactiveDismissDisabled(isJoining)
    }

    @ViewBuilder
    private var content: some View {
        if let preview {
            SquabbleImageView(preview.image, size: 120)
            VStack(spacing: 8) {
                Text("You're invited to", comment: "Join sheet: line above the squabble's name.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Text(verbatim: preview.name)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("^[\(preview.memberCount) members](inflect: true) already squabbling", comment: "Join sheet: how many people are in the squabble.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            if let reason = blockingError(preview) {
                Text(verbatim: reason.localizedDescription)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
        } else if let failure {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 30))
                .accessibilityHidden(true)
            Text(verbatim: failure.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)
            if failure == .needsInternet || failure == .unavailable {
                Button {
                    Task { await load() }
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

    @ViewBuilder
    private var button: some View {
        if let preview, blockingError(preview) == nil {
            Button {
                Task { await join() }
            } label: {
                if isJoining {
                    ProgressView().tint(.backdropDeep)
                } else if preview.isMember {
                    Text("Open squabble", comment: "Join sheet: button when the user is already a member.")
                } else {
                    Text("Join the squabble", comment: "Join sheet: button that joins.")
                }
            }
            .buttonStyle(.squabblePrimary)
            .disabled(isJoining)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: 560)
        }
    }

    private func blockingError(_ preview: InvitePreview) -> InviteError? {
        guard !preview.isMember else { return nil }
        if preview.isArchived { return .archived }
        if preview.isFull { return .full }
        return nil
    }

    private func load() async {
        failure = nil
        do {
            preview = try await invites.preview(code: invite.code)
        } catch {
            failure = error
        }
    }

    private func join() async {
        guard let preview else { return }
        isJoining = true
        defer { isJoining = false }
        do {
            let groupID = preview.isMember ? preview.groupID : try await invites.join(code: invite.code)
            // Push only once home's listener has the squabble, or its page would say it's gone.
            for _ in 0..<50 where groups.group(id: groupID) == nil {
                try? await Task.sleep(for: .milliseconds(200))
            }
            dismiss()
            onJoined(groupID)
        } catch {
            self.preview = nil
            failure = error
        }
    }
}
