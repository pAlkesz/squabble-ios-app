import SwiftUI

enum FocusOnAppear {
    typealias KeyboardType = UIKeyboardType
    typealias ReturnKeyType = UIReturnKeyType

    /// Input traits for the hidden field. They have to match the real field,
    /// or the keyboard visibly reconfigures itself as focus hands over.
    struct Configuration {
        let keyboardType: KeyboardType
        let returnKeyType: ReturnKeyType
        let isSecure: Bool
        let languageCode: String?

        init(
            keyboardType: KeyboardType = .default,
            returnKeyType: ReturnKeyType = .default,
            isSecure: Bool = false,
            languageCode: String? = nil
        ) {
            self.keyboardType = keyboardType
            self.returnKeyType = returnKeyType
            self.isSecure = isSecure
            self.languageCode = languageCode
        }

        static let `default` = Configuration()
    }
}

/// Takes first responder from its own initialiser — before the sheet has begun
/// presenting — which is what lets UIKit raise the keyboard in the same
/// animation instead of a second one afterwards.
private final class FirstResponderField: UITextField {
    private let languageCode: String?

    init(_ config: FocusOnAppear.Configuration) {
        languageCode = config.languageCode
        super.init(frame: .zero)
        keyboardType = config.keyboardType
        returnKeyType = config.returnKeyType
        isSecureTextEntry = config.isSecure
        becomeFirstResponder()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var textInputMode: UITextInputMode? {
        guard let languageCode else { return super.textInputMode }
        let requested = UITextInputMode.activeInputModes.first { mode in
            guard let primary = mode.primaryLanguage else { return false }
            return Locale(identifier: primary).language.languageCode?
                .identifier == languageCode
        }
        return requested ?? super.textInputMode
    }
}

private struct FirstResponderFieldView: UIViewRepresentable {
    let config: FocusOnAppear.Configuration

    func makeUIView(context: Context) -> FirstResponderField {
        FirstResponderField(config)
    }

    func updateUIView(_ uiView: FirstResponderField, context: Context) {}
}

private struct FocusOnAppearModifier<Value: Hashable>: ViewModifier {
    let condition: FocusState<Value>.Binding
    let value: Value
    let config: FocusOnAppear.Configuration

    func body(content: Content) -> some View {
        ZStack {
            FirstResponderFieldView(config: config)
                .frame(width: 0, height: 0)
                .opacity(0)
            content
                .focused(condition, equals: value)
                .onAppear { condition.wrappedValue = value }
        }
    }
}

private struct UnconditionalFocusOnAppearModifier: ViewModifier {
    let config: FocusOnAppear.Configuration

    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        ZStack {
            FirstResponderFieldView(config: config)
                .frame(width: 0, height: 0)
                .opacity(0)
            content
                .focused($focused)
                .onAppear { focused = true }
        }
    }
}

extension View {
    /// Focuses this field as the view appears, with the keyboard animating in
    /// alongside the presentation rather than after it.
    ///
    /// Only has that effect inside a `sheet`; in a `NavigationStack` push the
    /// keyboard animation comes out glitchy.
    func focusOnAppear(
        config: FocusOnAppear.Configuration = .default
    ) -> some View {
        modifier(UnconditionalFocusOnAppearModifier(config: config))
    }

    /// As `focusOnAppear(config:)`, binding the field's focus state to
    /// `condition`.
    func focusOnAppear(
        _ condition: FocusState<Bool>.Binding,
        config: FocusOnAppear.Configuration = .default
    ) -> some View {
        modifier(
            FocusOnAppearModifier(
                condition: condition,
                value: true,
                config: config
            )
        )
    }

    /// As `focusOnAppear(config:)`, binding focus to `condition` matching
    /// `value`.
    func focusOnAppear<Value: Hashable>(
        _ condition: FocusState<Value>.Binding,
        equals value: Value,
        config: FocusOnAppear.Configuration = .default
    ) -> some View {
        modifier(
            FocusOnAppearModifier(
                condition: condition,
                value: value,
                config: config
            )
        )
    }
}
