import SwiftUI

/// A squabble, laid out like Revolut's group page: the name in the bar with the picture
/// beside it (which opens the info page), the bills in the middle, and "Add a bill" at the
/// bottom. Until bills land the middle is a "ready" state.
struct SquabbleView: View {
    let groupID: String

    @Environment(GroupsStore.self) private var groups
    @State private var isInviting = false

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
        .background { backdrop }
    }

    /// Home's balance mood, for this squabble's balance instead of the total; neutral while
    /// the squabble is loading or gone.
    private var backdrop: some View {
        let group = groups.group(id: groupID)
        let mood = BalanceMood(
            amount: group.map(balance(in:)) ?? 0,
            currencyCode: group?.currencyCode ?? "EUR"
        )
        return SquabbleBackdrop(palette: mood.palette)
            .animation(.smooth(duration: 1.2), value: mood)
    }

    /// The user's balance in this squabble: positive when they're owed. Nothing to add up
    /// until bills land.
    private func balance(in group: SquabbleGroup) -> Decimal {
        0
    }

    private func content(_ group: SquabbleGroup) -> some View {
        ScrollView {
            ready(group)
                .padding(16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                // Centred in the space between the bars while there's nothing to scroll.
                .containerRelativeFrame(.vertical) { height, _ in height }
        }
        // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])

        .navigationTitle(Text(verbatim: group.name))
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(verbatim: group.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("No bills yet", comment: "Squabble page: subtitle under the name in the bar while there are no bills.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: HomeRoute.squabbleInfo(id: group.id)) {
                    SquabbleImageView(group.image, size: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Squabble info", comment: "Squabble page: VoiceOver label for the picture in the bar, which opens the squabble's info page."))
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .safeAreaBar(edge: .bottom) {
            // Bills aren't built yet.
            SquabbleGlassButton(title: "Add a bill", systemImage: "plus") {}
                .disabled(true)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: 560)
        }
    }

    private func ready(_ group: SquabbleGroup) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 30))
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Your squabble is ready", comment: "Squabble page: title while there are no bills yet.")
                    .font(.headline)
                Text(memberLine(group))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Add bills, then settle up", comment: "Squabble page: first point in the 'ready' card.")
                } icon: {
                    Image(systemName: "checkmark")
                }
                Label {
                    Text("Bring people in. They'll need the app too, no freeloaders.", comment: "Squabble page: second point in the 'ready' card. Members must have an account.")
                } icon: {
                    Image(systemName: "person.2.fill")
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
            if !group.isArchived {
                Button {
                    isInviting = true
                } label: {
                    Label {
                        Text("Invite people", comment: "Squabble info: button that opens the invite link and QR code.")
                    } icon: {
                        Image(systemName: "qrcode")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.backdropDeep)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isInviting) {
            SquabbleInviteSheet(groupID: group.id)
                .presentationBackground { ProfileBackdrop() }
        }
    }

    private func memberLine(_ group: SquabbleGroup) -> String {
        let count = group.currentMembers.count
        if count <= 1 {
            return String(localized: "Just you so far. Squabbling alone is called thinking.", comment: "Squabble page: under the 'ready' title when the user is the only member.")
        }
        return String(localized: "\(count) members, zero bills. For now.", comment: "Squabble page: under the 'ready' title when there are other members.")
    }
}
