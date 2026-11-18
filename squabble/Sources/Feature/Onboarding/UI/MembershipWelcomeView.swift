import SwiftUI

/// Played once, over home, right after onboarding saves the profile: the new Squabble Club
/// card slides up as if printed, gets stamped, then shrinks off towards the avatar in home's
/// toolbar — where the profile lives from now on. Tap to skip.
struct MembershipWelcomeView: View {
    let profile: UserProfile
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.hidden

    private enum Phase: Int, Comparable {
        case hidden
        case printed
        case stamped
        case leaving

        static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ProfileBackdrop()
                    .opacity(phase == .leaving ? 0 : 1)
                VStack(spacing: 28) {
                    card(in: proxy)
                    caption
                        .opacity(phase == .stamped ? 1 : 0)
                        .offset(y: phase == .stamped ? 0 : 12)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .contentShape(.rect)
        .onTapGesture { finish() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: phase == .stamped)
        .task { await play() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finish() }
    }

    private func card(in proxy: GeometryProxy) -> some View {
        MembershipCard(profile: profile) {
            AvatarView(profile.avatar, size: 88, cornerRadius: 12)
        }
        .overlay(alignment: .bottomTrailing) { stamp }
        .rotationEffect(.degrees(phase >= .printed ? 0 : 8))
        .scaleEffect(isFlyingOff ? 0.1 : 1)
        .offset(cardOffset(in: proxy))
        .opacity(phase == .leaving ? 0 : 1)
    }

    private var stamp: some View {
        Text("APPROVED", comment: "Welcome animation: the rubber stamp thumped onto the new membership card.")
            .font(.system(.title2, design: .monospaced, weight: .black))
            .tracking(2)
            .foregroundStyle(Color.red.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.red.opacity(0.85), lineWidth: 3)
            }
            .rotationEffect(.degrees(-14))
            .scaleEffect(phase >= .stamped ? 1 : 2.6)
            .opacity(phase >= .stamped ? 1 : 0)
            .padding(.trailing, 22)
            .padding(.bottom, 22)
            .accessibilityHidden(true)
    }

    private var caption: some View {
        VStack(spacing: 6) {
            Text("Welcome to the club, \(profile.displayName).", comment: "Welcome animation: headline under the new membership card, with the user's name.")
                .font(.title3.bold())
            Text("Dues are payable in guilt.", comment: "Welcome animation: joke line under the welcome headline.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
    }

    /// With Reduce Motion the card just fades out with the rest.
    private var isFlyingOff: Bool {
        phase == .leaving && !reduceMotion
    }

    /// Below the screen before it's printed; on the way out, up towards the toolbar avatar
    /// (leading edge, just under the status bar). Faked rather than matched: the avatar
    /// lives in another navigation bar.
    private func cardOffset(in proxy: GeometryProxy) -> CGSize {
        switch phase {
        case .hidden:
            return CGSize(width: 0, height: proxy.size.height)
        case .printed, .stamped:
            return .zero
        case .leaving where reduceMotion:
            return .zero
        case .leaving:
            let avatar = CGPoint(x: 36, y: 22)
            let cardCenter = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2 - 40)
            return CGSize(width: avatar.x - cardCenter.x, height: avatar.y - cardCenter.y)
        }
    }

    private func play() async {
        if reduceMotion {
            phase = .stamped
            try? await Task.sleep(for: .seconds(2.2))
            finish()
            return
        }
        // Home mounts underneath first; animating through that stall stutters on a device.
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.spring(duration: 0.8, bounce: 0.2)) { phase = .printed }
        try? await Task.sleep(for: .seconds(0.9))
        withAnimation(.spring(duration: 0.3, bounce: 0.35)) { phase = .stamped }
        try? await Task.sleep(for: .seconds(2.0))
        finish()
    }

    private func finish() {
        guard phase != .leaving else { return }
        withAnimation(.smooth(duration: 0.6)) { phase = .leaving }
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            onFinished()
        }
    }
}
