import FactoryKit
import SwiftUI

/// The invite link with a QR button beside it, like Revolut's: the link opens the share
/// sheet, the button the QR overlay. Until the link is known (never made, and offline) the
/// whole row opens the overlay, which offers a retry.
struct SquabbleInviteRow: View {
    let group: SquabbleGroup
    let onShowQRCode: () -> Void

    @Injected(\.inviteRepository) private var invites
    @State private var fetchedCode: String?

    var body: some View {
        HStack(spacing: 4) {
            if let url {
                ShareLink(item: url) {
                    label(Text(verbatim: InviteLink.displayText(for: url)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Share invite link", comment: "Squabble page: VoiceOver label for the invite link, which opens the share sheet."))
            } else {
                Button(action: onShowQRCode) {
                    label(Text("Invite people", comment: "Squabble info: button that opens the invite link and QR code."))
                }
                .buttonStyle(.plain)
            }
            Button(action: onShowQRCode) {
                Image(systemName: "qrcode")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Show QR code", comment: "Squabble page: VoiceOver label for the button beside the invite link that shows its QR code."))
        }
        .foregroundStyle(.white)
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
        .task(id: group.id) {
            guard group.inviteCode == nil, fetchedCode == nil else { return }
            fetchedCode = try? await invites.inviteCode(for: group.id)
        }
    }

    private var url: URL? {
        // The group's own copy first: it follows a reset, a fetched one doesn't.
        (group.inviteCode ?? fetchedCode).flatMap(InviteLink.url(code:))
    }

    private func label(_ text: Text) -> some View {
        text
            .font(.body.weight(.medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
    }
}
