import SwiftUI

/// The hub of the app: the user's overall balance, with the account behind the avatar
/// and search / new squabble in the top bar. One navigation stack, no tab bar — every
/// squabble is pushed from here. The account zooms out of the avatar over a blurred home.
struct HomeView: View {
    private static let space = "home"

    @Environment(AuthSession.self) private var session
    @State private var isShowingAccount = false
    @State private var avatarFrame: CGRect = .zero

    var body: some View {
        ZStack {
            home
                .zoomPresentationBackdrop(isActive: isShowingAccount)
            AccountView { setShowingAccount(false) }
                .zoomPresentation(isPresented: isShowingAccount, from: avatarFrame)
        }
        .coordinateSpace(.named(Self.space))
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
            .safeAreaBar(edge: .top) { topBar }
            .background { SquabbleBackdrop() }
            .containerBackground(.clear, for: .navigation)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var topBar: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                Button {
                    setShowingAccount(true)
                } label: {
                    avatar
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: {
                            avatarFrame = $0
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Account")

                Button {} label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .labelStyle(SearchPillLabelStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 44)
                        .padding(.horizontal, 16)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)

                Button {} label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("New squabble")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var avatar: some View {
        if let profile = session.profile {
            AvatarView(profile.avatar, size: 44)
        } else {
            AvatarView(content: .empty, size: 44)
        }
    }

    private func setShowingAccount(_ isShowing: Bool) {
        withAnimation(.zoomPresentation) { isShowingAccount = isShowing }
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
    }
}
