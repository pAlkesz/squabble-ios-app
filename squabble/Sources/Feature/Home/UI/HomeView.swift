import SwiftUI

/// The hub of the app: the user's overall balance, with the account behind the avatar
/// and search / new squabble in the toolbar. One navigation stack, no tab bar — every
/// squabble is pushed from here. The account slides up as a sheet. The backdrop takes
/// its colour from the balance (`BalanceMood`).
struct HomeView: View {
    @Environment(AuthSession.self) private var session
    @State private var isShowingAccount = false
    #if DEBUG
    @State private var debugBalance: Double?
    #endif

    var body: some View {
        home
            .sheet(isPresented: $isShowingAccount) {
                AccountView { isShowingAccount = false }
                    // A frosted blur of home's backdrop, in the balance's colour. At full height iOS puts an opaque layer
                    // under every sheet (a clear background shows grey), so a material only
                    // blurs grey; this blurs our own backdrop instead.
                    .presentationBackground {
                        SquabbleBackdrop(palette: mood.palette)
                            .blur(radius: 30)
                            .overlay(.ultraThinMaterial)
                    }
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
            .background {
                SquabbleBackdrop(palette: mood.palette)
                    .animation(.smooth(duration: 1.2), value: mood)
            }
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
