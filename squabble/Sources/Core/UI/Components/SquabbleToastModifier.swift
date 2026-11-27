import SwiftUI

/// Shows a `SquabbleToast` at the bottom of the safe area (above a bottom bar, when the
/// modified view is the one the bar insets) and clears it after a couple of seconds.
struct SquabbleToastModifier: ViewModifier {
    @Binding var toast: SquabbleToast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let duration: Duration = .seconds(2)

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast {
                    label(toast)
                        .id(toast.id)
                        .padding(.bottom, 12)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9, anchor: .bottom)))
                        .allowsHitTesting(false)
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.25), value: toast?.id)
            .task(id: toast?.id) {
                guard let shown = toast else { return }
                AccessibilityNotification.Announcement(String(localized: shown.title)).post()
                try? await Task.sleep(for: Self.duration)
                // Only the one this task was started for: a newer toast has its own clock.
                if toast?.id == shown.id { toast = nil }
            }
    }

    private func label(_ toast: SquabbleToast) -> some View {
        Label {
            Text(toast.title)
        } icon: {
            Image(systemName: toast.systemImage)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
    }
}

extension View {
    func squabbleToast(_ toast: Binding<SquabbleToast?>) -> some View {
        modifier(SquabbleToastModifier(toast: toast))
    }
}
