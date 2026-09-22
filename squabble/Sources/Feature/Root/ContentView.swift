//
//  ContentView.swift
//  squabble
//
//  Created by Personal on 2026. 09. 06..
//

import SwiftUI

/// Root router: picks the screen from the auth state and owns the shared `AuthSession`.
struct ContentView: View {
    @State private var session = AuthSession()

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ProgressView()
            case .signedOut:
                SignInView()
            case .needsOnboarding(let user):
                OnboardingView(user: user)
            case .profileUnavailable:
                ProfileUnavailableView()
            case .signedIn:
                HomeView()
            }
        }
        .animation(.default, value: session.state)
        .environment(session)
        .task { await session.observe() }
    }
}
