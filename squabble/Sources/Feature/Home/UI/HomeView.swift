import SwiftUI

/// The hub of the app: the user's overall balance, with the account behind the avatar
/// and search / new squabble in the toolbar. One navigation stack, no tab bar — every
/// squabble is pushed from here. The account slides up as a sheet.
struct HomeView: View {
    @Environment(AuthSession.self) private var session
    @State private var isShowingAccount = false

    var body: some View {
        home
            .sheet(isPresented: $isShowingAccount) {
                AccountView { isShowingAccount = false }
                    // A frosted blur of home's green. At full height iOS puts an opaque layer
                    // under every sheet (a clear background shows grey), so a material only
                    // blurs grey; this blurs our own backdrop instead.
                    .presentationBackground {
                        SquabbleBackdrop()
                            .blur(radius: 30)
                            .overlay(.ultraThinMaterial)
                    }
            }
    }

    private var home: some View {
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
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Borderless: the toolbar's glass hidden, so the avatar shows edge to edge.
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isShowingAccount = true
            } label: {
                avatar
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
