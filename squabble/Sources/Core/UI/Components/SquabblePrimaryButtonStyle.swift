import SwiftUI

/// The app's main call to action: a solid white capsule with dark text, matching the
/// Sign in with Apple button so the primary action reads the same on every screen.
/// Disabled stays opaque (solid grey) so content scrolling behind it never shows through.
struct SquabblePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.backdropDeep : Color.buttonDisabledLabel)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isEnabled ? Color.white : Color.buttonDisabledFill, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SquabblePrimaryButtonStyle {
    static var squabblePrimary: SquabblePrimaryButtonStyle { .init() }
}
