import SwiftUI

/// The hub of the app: the user's overall balance and their squabbles, with the account
/// behind the avatar and search / new squabble in the toolbar. One navigation stack, no tab bar — every
/// squabble is pushed from here, and so is the account. The backdrop takes its colour from
/// the total (`BalanceMood`); a squabble's pages take theirs from its own balance, and pages
/// without a balance stay quiet.
struct HomeView: View {
    @Environment(AuthSession.self) private var session
    @Environment(InviteInbox.self) private var inviteInbox
    @Environment(\.reportAvatarFrame) private var reportAvatarFrame
    @Environment(\.isMembershipWelcomeShowing) private var isWelcomeShowing
    @State private var preferences = PreferencesStore()
    @State private var groups = GroupsStore()
    @State private var rates = RatesStore()
    @State private var path: [HomeRoute] = []
    @State private var isCreatingSquabble = false
    @State private var newSquabbleSource = NewSquabbleSource.homeToolbar
    @Namespace private var transitions
    #if DEBUG
    @State private var debugBalance: Double?
    @State private var debugBalances = DebugBalances()
    #endif

    var body: some View {
        home
            .task(id: session.user?.id) {
                guard let uid = session.user?.id else { return }
                async let preferences: Void = preferences.observe(uid: uid)
                async let groups: Void = groups.observe(uid: uid)
                async let rates: Void = rates.observe()
                _ = await (preferences, groups, rates)
            }
            .onChange(of: session.profile, initial: true) { _, profile in
                groups.profile = profile
            }
            // Signing out happens from the Membership page; the next sign-in should land on
            // home, not back where the last one left off.
            .onChange(of: session.user == nil) { _, isSignedOut in
                if isSignedOut { path.removeAll() }
            }
    }

    private var home: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 24) {
                    TotalBalanceView(
                        amount: balance,
                        currencyCode: headlineCurrencyCode,
                        others: total.others
                    )
                        .frame(maxWidth: .infinity)
                        // Uneven because the number's line box reaches below its digits: what
                        // you see is centred between the toolbar and the first tile.
                        .padding(.top, 52)
                        .padding(.bottom, 28)
                    #if DEBUG
                        .onLongPressGesture {
                            debugBalance = debugBalance == nil ? 0 : nil
                        }
                    #endif
                    #if DEBUG
                    debugBalanceSlider
                    #endif
                    squabbleList
                }
                .padding(.horizontal, 16)
            }
            // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background { backdrop }
            .containerBackground(.clear, for: .navigation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .squabbles:
                    SquabbleListView(transitions: transitions) {
                        startSquabble(from: .listToolbar)
                    }
                        .background { QuietBackdrop() }
                        .containerBackground(.clear, for: .navigation)
                case .squabble(let id):
                    // Paints its own backdrop, tinted by the squabble's balance.
                    SquabbleView(groupID: id)
                        .containerBackground(.clear, for: .navigation)
                case .squabbleInfo(let id):
                    SquabbleInfoView(groupID: id)
                        .background { SquabbleMoodBackdrop(groupID: id, isDimmed: true) }
                        .containerBackground(.clear, for: .navigation)
                case .account(let page):
                    accountPage(page)
                        .background { ProfileBackdrop() }
                        .containerBackground(.clear, for: .navigation)
                }
            }
            .sheet(isPresented: $isCreatingSquabble) {
                if let profile = session.profile {
                    NewSquabbleView(creator: profile, currencyCode: homeCurrencyCode) { id in
                        push(.squabble(id: id))
                    }
                    .presentationBackground(Color.backdropDeep)
                    .tint(.white)
                    // Grows out of the + button's glass and shrinks back into it.
                    .navigationTransition(.zoom(sourceID: newSquabbleSource, in: transitions))
                }
            }
        }
        // Held back while the membership welcome is up, so a link opened before signing up
        // shows once the new member is home.
        .sheet(item: Binding(
            get: { isWelcomeShowing ? nil : inviteInbox.pending },
            set: { inviteInbox.pending = $0 }
        )) { invite in
            JoinSquabbleSheet(invite: invite) { push(.squabble(id: $0)) }
                .presentationBackground { ProfileBackdrop() }
                .presentationDetents([.medium, .large])
        }
        // The system back button follows the stack's tint.
        .tint(.white)
        .environment(preferences)
        .environment(groups)
        .environment(rates)
        #if DEBUG
        .environment(debugBalances)
        #endif
        .environment(\.showAccountPage, ShowAccountPageAction { push(.account($0)) })
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // Borderless: the toolbar's glass hidden, so the avatar shows edge to edge.
        ToolbarItem(placement: .topBarLeading) {
            Button {
                push(.account(.account))
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
            Button {
                startSquabble(from: .homeToolbar)
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(.white)
            }
            .disabled(session.profile == nil)
            .accessibilityLabel("New squabble")
        }
        .matchedTransitionSource(id: NewSquabbleSource.homeToolbar, in: transitions)
    }

    /// Pushed pages carry their own backdrop, as onboarding's pages do: a shared one behind the
    /// stack would show both pages' content overlapping mid-push.
    private var backdrop: some View {
        SquabbleBackdrop(palette: mood.palette)
            .animation(.smooth(duration: 1.2), value: mood)
    }

    private func startSquabble(from source: NewSquabbleSource) {
        newSquabbleSource = source
        isCreatingSquabble = true
    }

    private func push(_ route: HomeRoute) {
        guard path.last != route else { return }
        path.append(route)
    }

    /// Hidden until the first answer, so a returning user never sees the empty state flash.
    @ViewBuilder
    private var squabbleList: some View {
        if groups.hasLoaded {
            HomeTile(
                title: Text("Squabbles", comment: "Home: title of the tile listing the user's squabbles."),
                destination: groups.groups.isEmpty ? nil : .squabbles
            ) {
                if groups.groups.isEmpty {
                    emptySquabbles
                } else {
                    // The most recently active few; the rest are behind "See all".
                    ForEach(groups.groups.prefix(Self.tileSquabbleCount)) { group in
                        NavigationLink(value: HomeRoute.squabble(id: group.id)) {
                            SquabbleRow(group: group, pictureSize: 48)
                        }
                        .buttonStyle(.plain)
                        .transition(SquabbleRow.arrival)
                    }
                }
            }
            // A squabble someone else starts, or one that just got busy, slides into place.
            .animation(SquabbleRow.reorder, value: groups.groups.prefix(Self.tileSquabbleCount).map(\.id))
            .frame(maxWidth: 640)
            .transition(.opacity)
        }
    }

    private static let tileSquabbleCount = 3

    private var emptySquabbles: some View {
        VStack(spacing: 14) {
            Text(verbatim: "🕊️")
                .font(.system(size: 34))
                .frame(width: 64, height: 64)
                .background(.white.opacity(0.12), in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("No squabbles yet", comment: "Home: title when the user has no squabbles.")
                    .font(.headline)
                Text("Suspiciously peaceful around here. Nobody owes anybody anything… yet.", comment: "Home: message when the user has no squabbles.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            Button {
                startSquabble(from: .homeEmptyState)
            } label: {
                Label {
                    Text("Start a squabble", comment: "Home: button in the empty squabbles tile that opens the create sheet.")
                } icon: {
                    Image(systemName: "plus")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.backdropDeep)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.white, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(session.profile == nil)
            .matchedTransitionSource(id: NewSquabbleSource.homeEmptyState, in: transitions)
            .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
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
        Group {
            if let profile = session.profile {
                AvatarView(profile.avatar, size: 40)
            } else {
                AvatarView(content: .empty, size: 40)
            }
        }
        // The membership welcome flies the card's photo onto this spot, then hands over.
        .opacity(isWelcomeShowing ? 0 : 1)
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { reportAvatarFrame($0) }
    }

    private var mood: BalanceMood {
        #if DEBUG
        if debugBalance != nil {
            return BalanceMood(amount: balance, currencyCode: homeCurrencyCode, rates: rates.rates)
        }
        #endif
        return BalanceMood(balances: [total.headline] + total.others, rates: rates.rates)
    }

    private var headlineCurrencyCode: String {
        #if DEBUG
        if debugBalance != nil { return homeCurrencyCode }
        #endif
        return total.headline.currencyCode
    }

    private var total: HomeTotal {
        HomeTotal(
            groups: groups.groups,
            uid: session.user?.id ?? "",
            homeCurrencyCode: homeCurrencyCode,
            rates: rates.rates
        )
    }

    private var balance: Decimal {
        #if DEBUG
        if let debugBalance {
            return Decimal(Int(debugBalance.rounded()))
        }
        #endif
        return total.headline.amount
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
