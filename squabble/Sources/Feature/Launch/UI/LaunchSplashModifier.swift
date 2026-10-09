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
    ///
    /// The bird waits in its final pose until `isContentReady`. `onReadyForContent` is
    /// called once it's standing still: build the first real screen then, not earlier —
    /// mounting it stalls the main thread, which stutters the intro on a device.
    /// While it waits it shows it's loading, unless `hasError` says an error is up instead.
    func launchSplash(
        isContentReady: Bool,
        hasError: Bool = false,
        onReadyForContent: @escaping @MainActor () -> Void
    ) -> some View {
        modifier(LaunchSplashModifier(
            isContentReady: isContentReady,
            hasError: hasError,
            onReadyForContent: onReadyForContent
        ))
    }
}

private struct LaunchSplashModifier: ViewModifier {
    let isContentReady: Bool
    let hasError: Bool
    let onReadyForContent: @MainActor () -> Void
    @State private var isPresented = true

    // A ZStack rather than `.overlay` so the splash takes the whole window instead
    // of the root view's own size.
    func body(content: Content) -> some View {
        ZStack {
            content
                .environment(\.isLaunchSplashFinished, !isPresented)
            if isPresented {
                LaunchSplashView(
                    isContentReady: isContentReady,
                    hasError: hasError,
                    onReadyForContent: onReadyForContent,
                    onFinished: { isPresented = false }
                )
            }
        }
    }
}
