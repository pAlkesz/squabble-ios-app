import SwiftUI

/// Opened from the picture in a squabble's bar: the picture, name and currency, and who's in
/// it. Editing, inviting and leaving will live here.
struct SquabbleInfoView: View {
    let groupID: String

    @Environment(GroupsStore.self) private var groups
    @Environment(AuthSession.self) private var session

    var body: some View {
        Group {
            if let group = groups.group(id: groupID) {
                content(group)
            } else if groups.hasLoaded {
                SquabbleUnavailableView()
            }
        }
        .foregroundStyle(.white)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ group: SquabbleGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(group)
                card(title: Text("Members · \(group.currentMembers.count)", comment: "Squabble page: header above the members, with how many there are.")) {
                    VStack(spacing: 0) {
                        ForEach(group.currentMembers) { member in
                            memberRow(member, in: group)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private func header(_ group: SquabbleGroup) -> some View {
        VStack(spacing: 12) {
            SquabbleImageView(group.image, size: 120)
            Text(verbatim: group.name)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(verbatim: CurrencyRow.detail(for: CurrencyOption(code: group.currencyCode)))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            if !group.isArchived {
                SquabbleInviteLink(group: group)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func card(title: Text, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            title
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 4)
            content()
                .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
        }
    }

    private func memberRow(_ member: GroupMember, in group: SquabbleGroup) -> some View {
        HStack(spacing: 12) {
            AvatarView(member.avatar, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: member.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                if let handle = member.handle {
                    Text(verbatim: handle.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 0)
            if member.id == session.user?.id {
                tag(Text("You", comment: "Squabble page: tag on the user's own row."))
            }
            if member.id == group.createdBy {
                tag(Text("Started it", comment: "Squabble page: tag on the row of whoever created (and runs) the squabble."))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func tag(_ text: Text) -> some View {
        text
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.14), in: .capsule)
    }
}
