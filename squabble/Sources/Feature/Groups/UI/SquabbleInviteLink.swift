import FactoryKit
import SwiftUI

/// The shortened invite link and a QR symbol under a squabble's name, like Revolut's. The
/// whole thing is one button that opens the invite sheet. Until the link is known (never
/// made, and offline) it says "Invite people"; the sheet offers a retry.
struct SquabbleInviteLink: View {
    let group: SquabbleGroup

    @Injected(\.inviteRepository) private var invites
    @State private var fetchedCode: String?
    @State private var isInviting = false

    var body: some View {
        Button {
            isInviting = true
        } label: {
            HStack(spacing: 6) {
                title
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "qrcode")
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.75))
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Invite link and QR code", comment: "Squabble page: VoiceOver label for the invite link, which opens the sheet with the QR code."))
        .task(id: group.id) {
            guard group.inviteCode == nil, fetchedCode == nil else { return }
            fetchedCode = try? await invites.inviteCode(for: group.id)
        }
        .sheet(isPresented: $isInviting) {
            SquabbleInviteSheet(groupID: group.id)
        }
    }

    private var title: Text {
        // The group's own copy first: it follows a reset, a fetched one doesn't.
        if let code = group.inviteCode ?? fetchedCode, let text = InviteLink.displayText(code: code) {
            Text(verbatim: text)
        } else {
            Text("Invite people", comment: "Squabble info: button that opens the invite link and QR code.")
        }
    }
}
