//
//  ContentView.swift
//  squabble
//
//  Created by Personal on 2026. 09. 06..
//

import SwiftUI

/// Root router: picks the screen from the auth state and owns the shared `AuthSession`.
/// There's no loading screen — the launch splash waits for the first answer, and after
/// that the current screen stays up while the next one is worked out.
struct ContentView: View {
    private enum Route {
        case signInFlow
        case home
    }

    @State private var session = AuthSession()
    @State private var inviteInbox = InviteInbox()
    /// Nil until the splash says the bird is standing still; see `launchSplash`.
    @State private var route: Route?
    @State private var canMountRoute = false
    /// Set only when onboarding has just saved the profile, never for a returning user.
    @State private var welcome: UserProfile?
    @State private var avatarFrame: CGRect?

    var body: some View {
        // A ZStack with explicit transitions: the two roots are separate navigation stacks,
        // and swapping them in a plain Group didn't pick up an implicit animation.
        ZStack {
            switch route {
            case nil:
                // Only ever behind the splash, which is the same colour.
                Color.accent.ignoresSafeArea()
            case .signInFlow:
                OnboardingFlowView()
                    .transition(.opacity)
            case .home:
                HomeView()
                    .transition(.opacity)
            }
        }
        .environment(\.reportAvatarFrame, AvatarFrameReporter { avatarFrame = $0 })
        .environment(\.isMembershipWelcomeShowing, welcome != nil)
        .overlay {
            if let welcome {
                MembershipWelcomeView(profile: welcome, avatarFrame: avatarFrame) { self.welcome = nil }
                    // Fades in; leaves instantly, as the photo has just landed on the avatar.
                    .transition(.opacity)
            }
        }
        .launchSplash(isContentReady: route != nil, hasError: session.profileSync != .live) {
            canMountRoute = true
            updateRoute()
        }
        .sheet(isPresented: .constant(session.profileSync != .live)) {
            ProfileSyncFailedSheet()
        }
        .task { await session.observe() }
        // Universal links arrive here too; an invite waits in the inbox until home shows it.
        .onOpenURL { inviteInbox.receive($0) }
        .onChange(of: session.state, initial: true) { previous, state in
            // Set before the route changes, so the welcome covers the swap to home.
            if case .needsOnboarding = previous, case .signedIn(_, let profile) = state {
                withAnimation(.smooth(duration: 0.4)) { welcome = profile }
            }
            updateRoute()
        }
        .environment(session)
        .environment(inviteInbox)
    }

    private func updateRoute() {
        guard canMountRoute, let next = Self.route(for: session.state) else { return }
        // The first screen appears under the splash, so it shouldn't fade in as well.
        withAnimation(route == nil ? nil : .smooth(duration: 0.6)) { route = next }
    }

    /// Nil while still loading: stay on the current screen. Right after signing in that's
    /// the sign-in flow, and onboarding is pushed onto its stack.
    private static func route(for state: AuthSession.State) -> Route? {
        switch state {
        case .loading: nil
        case .signedOut, .needsOnboarding: .signInFlow
        case .signedIn: .home
        }
    }
}
