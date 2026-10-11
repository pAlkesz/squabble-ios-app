import SwiftUI

/// The hub of the app: the user's overall balance, with the account behind the avatar
/// and search / new squabble in the toolbar. One navigation stack, no tab bar — every
/// squabble is pushed from here. The account zooms out of the avatar over a blurred home.
struct HomeView: View {
    @Environment(AuthSession.self) private var session
    @State private var accountZoom = ZoomPresenter()

    var body: some View {
        NavigationStack {
            ScrollView {
                // Nothing to total yet: groups and bills haven't landed.
                TotalBalanceView(amount: 0, currencyCode: homeCurrencyCode)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 72)
            }
            .background { SquabbleBackdrop() }
            .containerBackground(.clear, for: .navigation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        // The account is presented by UIKit, outside this view: signing out or deleting the
        // account swaps the root away from home, and it would otherwise stay on top.
        .onDisappear { accountZoom.dismiss(animated: false) }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: openAccount) {
                avatar
                    .zoomSource(for: accountZoom)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account")
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .principal) {
            Button {} label: {
                Label("Search", systemImage: "magnifyingglass")
                    .labelStyle(SearchPillLabelStyle())
            }
            .buttonStyle(.plain)
            // The principal slot gets no glass of its own.
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .topBarTrailing) {
            // A styled label: toolbar buttons take the accent colour and ignore `.tint`.
            Button {} label: {
                Image(systemName: "plus")
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("New squabble")
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let profile = session.profile {
            AvatarView(profile.avatar, size: 40)
        } else {
            AvatarView(content: .empty, size: 40)
        }
    }

    private func openAccount() {
        let zoom = accountZoom
        zoom.present(
            AccountView(onClose: { zoom.dismiss() }, onAvatarFrameChange: { zoom.alignmentRect = $0 })
                .environment(session)
        )
    }

    // Until there's a currency setting, totals convert into the reader's local currency.
    private var homeCurrencyCode: String {
        Locale.current.currency?.identifier ?? "EUR"
    }
}

private struct SearchPillLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .font(.body.weight(.semibold))
            configuration.title
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.75))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(width: 220, height: 40, alignment: .leading)
        .contentShape(.capsule)
    }
}
