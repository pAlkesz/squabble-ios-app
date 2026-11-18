import SwiftUI

/// Played once, over home, right after onboarding saves the profile: the new Squabble Club
/// card slides up as if printed and gets stamped, then waits for the button. On the button
/// the card and text fade away while the card's photo flies onto home's toolbar avatar,
/// shrinking and rounding into it — where the profile lives from now on.
struct MembershipWelcomeView: View {
    let profile: UserProfile
    /// Where home's toolbar avatar sits on screen, once home has laid it out. Without it the
    /// photo just fades with the card.
    let avatarFrame: CGRect?
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.hidden
    /// The card's photo on screen, measured so the flying copy starts exactly on top of it.
    @State private var photoFrame: CGRect?
    @State private var hasPhotoLanded = false

    private static let photoSize: CGFloat = 88
    private static let photoCornerRadius: CGFloat = 12

    private enum Phase: Int, Comparable {
        case hidden
        case printed
        case stamped
        case leaving

        static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var body: some View {
        ZStack {
            ProfileBackdrop()
            // Laid out like the onboarding pages it follows: the heading on top, then the card
            // a little above centre (spacers 1 : 2), then the button.
            VStack(spacing: 0) {
                OnboardingHeading(
                    title: "Welcome to the club",
                    subtitle: "Your card's printed. Dues are payable in guilt."
                )
                .foregroundStyle(.white)
                .padding(.top, 16)
                .opacity(phase == .stamped ? 1 : 0)
                .offset(y: phase == .stamped ? 0 : -8)
                Spacer(minLength: 24)
                card
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { continueButton }
        }
        .opacity(phase == .leaving ? 0 : 1)
        .overlay { flyingPhoto }
        .sensoryFeedback(.impact(weight: .heavy), trigger: phase == .stamped)
        .task { await play() }
    }

    private var card: some View {
        MembershipCard(profile: profile) {
            AvatarView(profile.avatar, size: Self.photoSize, cornerRadius: Self.photoCornerRadius)
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { photoFrame = $0 }
                // Gone at once when its copy takes off, so the photo doesn't show twice.
                .opacity(isPhotoFlying ? 0 : 1)
                .animation(nil, value: isPhotoFlying)
        }
        .overlay(alignment: .bottomTrailing) { stamp }
        .rotationEffect(.degrees(phase >= .printed ? 0 : 8))
        .offset(y: phase >= .printed ? 0 : 900)
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

    private var continueButton: some View {
        Button(action: leave) {
            Text("Let's squabble", comment: "Welcome animation: the button that closes it and goes to home.")
        }
        .buttonStyle(.squabblePrimary)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: 560)
        .opacity(phase == .stamped ? 1 : 0)
        .disabled(phase != .stamped)
    }

    private var isPhotoFlying: Bool {
        phase == .leaving && !reduceMotion && photoFrame != nil && avatarFrame != nil
    }

    /// A copy of the card's photo that leaves it on the button: from the photo's frame to the
    /// avatar's, shrinking from 88 pt to the avatar's size while its corners round into a
    /// circle. Laid out in screen coordinates, so it ignores the safe area.
    @ViewBuilder
    private var flyingPhoto: some View {
        if phase == .leaving, !reduceMotion, let start = photoFrame, let end = avatarFrame {
            let frame = hasPhotoLanded ? end : start
            let scale = frame.width / Self.photoSize
            AvatarView(profile.avatar, size: Self.photoSize, cornerRadius: 0)
                .clipShape(.rect(cornerRadius: hasPhotoLanded ? Self.photoSize / 2 : Self.photoCornerRadius))
                .scaleEffect(scale)
                .position(x: frame.midX, y: frame.midY)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                // Appears fully opaque on top of the card's photo, not faded in with the rest.
                .transition(.identity)
        }
    }

    private func play() async {
        if reduceMotion {
            phase = .stamped
            return
        }
        // Home mounts underneath first; animating through that stall stutters on a device.
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.spring(duration: 0.8, bounce: 0.2)) { phase = .printed }
        try? await Task.sleep(for: .seconds(0.9))
        withAnimation(.spring(duration: 0.3, bounce: 0.35)) { phase = .stamped }
    }

    private func leave() {
        guard phase == .stamped else { return }
        // The flying copy appears on top of the card's photo in this update, unanimated; the
        // next one sends it on its way while everything else fades.
        withAnimation(.smooth(duration: 0.5)) { phase = .leaving }
        Task {
            // A frame for the copy to be drawn at its start first, or it would begin landed.
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(.spring(duration: 0.6, bounce: 0.15)) { hasPhotoLanded = true }
            try? await Task.sleep(for: .seconds(0.65))
            onFinished()
        }
    }
}
