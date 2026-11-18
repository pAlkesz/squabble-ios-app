import SwiftUI

/// The hub of the app: the user's overall balance and their squabbles, with the account
/// behind the avatar and search / new squabble in the toolbar. One navigation stack, no tab bar — every
/// squabble is pushed from here, and so is the account. The backdrop takes its colour from
/// the balance (`BalanceMood`), on home and on every page pushed from it.
struct HomeView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.reportAvatarFrame) private var reportAvatarFrame
    @Environment(\.isMembershipWelcomeShowing) private var isWelcomeShowing
    @State private var preferences = PreferencesStore()
    @State private var groups = GroupsStore()
    @State private var path: [HomeRoute] = []
    @State private var isCreatingSquabble = false
    @Namespace private var transitions
    #if DEBUG
    @State private var debugBalance: Double?
    #endif

    var body: some View {
        home
            .task(id: session.user?.id) {
                guard let uid = session.user?.id else { return }
                async let preferences: Void = preferences.observe(uid: uid)
                async let groups: Void = groups.observe(uid: uid)
                _ = await (preferences, groups)
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
                    squabbleList
                }
                .padding(.horizontal, 16)
                .padding(.top, 72)
            }
            // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background { backdrop }
            .containerBackground(.clear, for: .navigation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .squabble(let id):
                    SquabbleView(groupID: id)
                        .background { SquabbleBackdrop(palette: BalanceMood(amount: 0, currencyCode: homeCurrencyCode).palette) }
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
                    .navigationTransition(.zoom(sourceID: Self.newSquabbleTransition, in: transitions))
                }
            }
        }
        // The system back button follows the stack's tint.
        .tint(.white)
        .environment(preferences)
        .environment(groups)
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
                isCreatingSquabble = true
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(.white)
            }
            .disabled(session.profile == nil)
            .accessibilityLabel("New squabble")
        }
        .matchedTransitionSource(id: Self.newSquabbleTransition, in: transitions)
    }

    /// Pushed pages carry their own backdrop, as onboarding's pages do: a shared one behind the
    /// stack would show both pages' content overlapping mid-push.
    private var backdrop: some View {
        SquabbleBackdrop(palette: mood.palette)
            .animation(.smooth(duration: 1.2), value: mood)
    }

    private static let newSquabbleTransition = "newSquabble"

    private func push(_ route: HomeRoute) {
        guard path.last != route else { return }
        path.append(route)
    }

    /// Hidden until the first answer, so a returning user never sees the empty state flash.
    @ViewBuilder
    private var squabbleList: some View {
        if groups.hasLoaded {
            VStack(alignment: .leading, spacing: 8) {
                Text("Squabbles", comment: "Home: header above the list of squabbles.")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 4)
                if groups.groups.isEmpty {
                    emptySquabbles
                } else {
                    VStack(spacing: 0) {
                        ForEach(groups.groups) { group in
                            Button {
                                push(.squabble(id: group.id))
                            } label: {
                                SquabbleRow(group: group)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
                }
            }
            .frame(maxWidth: 640)
            .transition(.opacity)
        }
    }

    private var emptySquabbles: some View {
        VStack(spacing: 6) {
            Text("No squabbles yet", comment: "Home: title when the user has no squabbles.")
                .font(.headline)
            Text("Suspiciously peaceful. Tap + to start one.", comment: "Home: message when the user has no squabbles.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
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
        BalanceMood(amount: balance, currencyCode: homeCurrencyCode)
    }

    // Nothing to total yet: bills haven't landed.
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
