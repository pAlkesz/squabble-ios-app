import SwiftUI

/// The hub of the app: the user's overall balance, with the account behind the avatar
/// and search / new squabble in the toolbar. One navigation stack, no tab bar — every
/// squabble is pushed from here, and so is the account. The backdrop takes its colour from
/// the balance (`BalanceMood`), on home and on every page pushed from it.
struct HomeView: View {
    @Environment(AuthSession.self) private var session
    @State private var preferences = PreferencesStore()
    #if DEBUG
    @State private var debugBalance: Double?
    #endif

    var body: some View {
        home
            .task(id: session.user?.id) {
                guard let uid = session.user?.id else { return }
                await preferences.observe(uid: uid)
            }
    }

    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    TotalBalanceView(amount: balance, currencyCode: homeCurrencyCode)
                        .frame(maxWidth: .infinity)
                    #if DEBUG
                        .onLongPressGesture {
                            debugBalance = debugBalance == nil ? 0 : nil
                        }
                    #endif
                    #if DEBUG
                    debugBalanceSlider
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.top, 72)
            }
            .background { backdrop }
            .containerBackground(.clear, for: .navigation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(for: AccountPage.self) { page in
                accountPage(page)
                    .background { ProfileBackdrop() }
                    .containerBackground(.clear, for: .navigation)
            }
        }
        // The system back button follows the stack's tint.
        .tint(.white)
        .environment(preferences)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Borderless: the toolbar's glass hidden, so the avatar shows edge to edge.
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink(value: AccountPage.account) {
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

    /// Account pages carry their own backdrop, as onboarding's pages do: a shared one behind
    /// the stack would show both pages' content overlapping mid-push.
    private var backdrop: some View {
        SquabbleBackdrop(palette: mood.palette)
            .animation(.smooth(duration: 1.2), value: mood)
    }

    @ViewBuilder
    private func accountPage(_ page: AccountPage) -> some View {
        switch page {
        case .account: AccountView()
        case .displayName: DisplayNameEditView()
        case .paymentDetails: PaymentDetailsView()
        case .homeCurrency: HomeCurrencyPicker()
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

    private var mood: BalanceMood {
        BalanceMood(amount: balance, currencyCode: homeCurrencyCode)
    }

    // Nothing to total yet: groups and bills haven't landed.
    private var balance: Decimal {
        #if DEBUG
        if let debugBalance {
            return Decimal(Int(debugBalance.rounded()))
        }
        #endif
        return 0
    }

    #if DEBUG
    /// Long-press the total to drag the balance through every backdrop mood on a device.
    @ViewBuilder
    private var debugBalanceSlider: some View {
        if let value = debugBalance {
            let range = 300 * BalanceMood.unitsPerEuro(homeCurrencyCode)
            Slider(
                value: Binding(get: { value }, set: { debugBalance = $0 }),
                in: -range...range
            )
            .tint(.white)
        }
    }
    #endif

    private var homeCurrencyCode: String {
        preferences.homeCurrencyCode
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
