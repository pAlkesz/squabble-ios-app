import SwiftUI

extension View {
    /// Covers the view with `LaunchSplashView` on first appearance and removes it once
    /// the animation has finished. Apply once, to the root view.
    func launchSplash() -> some View {
        modifier(LaunchSplashModifier())
    }
}

private struct LaunchSplashModifier: ViewModifier {
    @State private var isPresented = true

    // A ZStack rather than `.overlay` so the splash takes the whole window instead
    // of the root view's own size.
    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                LaunchSplashView { isPresented = false }
            }
        }
    }
}
