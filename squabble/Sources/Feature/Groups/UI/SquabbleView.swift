import SwiftUI

/// A squabble, pushed from home: who's in it and, once bills land, who owes whom.
struct SquabbleView: View {
    let groupID: String

    @Environment(GroupsStore.self) private var groups
    @Environment(AuthSession.self) private var session

    var body: some View {
        Group {
            if let group = groups.group(id: groupID) {
                content(group)
            } else if groups.hasLoaded {
                ContentUnavailableView {
                    Label {
                        Text("This squabble is gone", comment: "Squabble page: the squabble no longer exists or the user left it.")
                    } icon: {
                        Image(systemName: "bird")
                    }
                } description: {
                    Text("Someone deleted it, or you're no longer in it.", comment: "Squabble page: explanation when the squabble is gone.")
                }
            }
        }
        .foregroundStyle(.white)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ group: SquabbleGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(group)
                card(title: Text("Bills", comment: "Squabble page: header above the bills.")) {
                    VStack(spacing: 6) {
                        Text("No bills yet", comment: "Squabble page: empty bills title.")
                            .font(.headline)
                        Text("Nobody owes anybody anything. Enjoy it while it lasts.", comment: "Squabble page: empty bills message.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 16)
                }
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
        .navigationTitle(Text(verbatim: group.name))
    }

    private func header(_ group: SquabbleGroup) -> some View {
        VStack(spacing: 12) {
            MemberAvatarStack(members: group.currentMembers, size: 56, limit: 4)
            Text(verbatim: group.name)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(verbatim: CurrencyRow.detail(for: CurrencyOption(code: group.currencyCode)))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
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
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
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
