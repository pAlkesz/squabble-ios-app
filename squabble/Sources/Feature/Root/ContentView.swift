//
//  ContentView.swift
//  squabble
//
//  Created by Personal on 2026. 09. 06..
//

import SwiftUI

/// Root router: picks the screen from the auth state and owns the shared `AuthSession`.
struct ContentView: View {
    private enum Route {
        case loading
        case signInFlow
        case profileUnavailable
        case home
    }

    @State private var session = AuthSession()
    @State private var route: Route = .loading

    var body: some View {
        Group {
            switch route {
            case .loading:
                ZStack {
                    SquabbleBackdrop()
                    ProgressView().tint(.white)
                }
            case .signInFlow:
                OnboardingFlowView()
            case .profileUnavailable:
                ProfileUnavailableView()
            case .home:
                HomeView()
            }
        }
        .animation(.default, value: route)
        .environment(session)
        .task { await session.observe() }
        .onChange(of: session.state, initial: true) { _, state in
            route = Self.route(for: state, from: route)
        }
    }

    /// While the profile loads right after signing in, stay on the sign-in flow instead of
    /// tearing it down for a spinner — onboarding is pushed onto that same stack.
    private static func route(for state: AuthSession.State, from current: Route) -> Route {
        switch state {
        case .loading: current == .signInFlow ? .signInFlow : .loading
        case .signedOut, .needsOnboarding: .signInFlow
        case .profileUnavailable: .profileUnavailable
        case .signedIn: .home
        }
    }
}
