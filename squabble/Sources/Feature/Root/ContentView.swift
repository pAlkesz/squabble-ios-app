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
    /// Nil until the splash says the bird is standing still; see `launchSplash`.
    @State private var route: Route?
    @State private var canMountRoute = false

    var body: some View {
        Group {
            switch route {
            case nil:
                // Only ever behind the splash, which is the same colour.
                Color.accent.ignoresSafeArea()
            case .signInFlow:
                OnboardingFlowView()
            case .home:
                HomeView()
            }
        }
        .animation(.default, value: route)
        .launchSplash(isContentReady: route != nil, hasError: session.profileSync != .live) {
            canMountRoute = true
            updateRoute()
        }
        .sheet(isPresented: .constant(session.profileSync != .live)) {
            ProfileSyncFailedSheet()
        }
        .task { await session.observe() }
        .onChange(of: session.state, initial: true) { updateRoute() }
        .environment(session)
    }

    private func updateRoute() {
        guard canMountRoute, let next = Self.route(for: session.state) else { return }
        // The first screen appears under the splash, so it shouldn't fade in as well.
        var transaction = Transaction()
        transaction.disablesAnimations = route == nil
        withTransaction(transaction) { route = next }
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
