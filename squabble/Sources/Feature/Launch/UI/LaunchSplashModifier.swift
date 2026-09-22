import SwiftUI

extension EnvironmentValues {
    /// False while the launch splash still covers the app. Screens whose entrance
    /// animation would otherwise play unseen behind it wait on this.
    /// Defaults to true so previews and tests animate straight away.
    @Entry var isLaunchSplashFinished = true
}

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
                .environment(\.isLaunchSplashFinished, !isPresented)
            if isPresented {
                LaunchSplashView { isPresented = false }
            }
        }
    }
}
