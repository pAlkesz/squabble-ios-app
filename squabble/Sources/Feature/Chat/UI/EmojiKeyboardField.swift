import SwiftUI
import UIKit

/// An invisible field that, while `isActive`, brings up the system emoji keyboard and hands
/// back the first emoji typed. SwiftUI has no emoji picker and can't choose a keyboard, so
/// this wraps a `UITextField` that asks for the emoji input mode; without one enabled, iOS
/// shows the usual keyboard and its globe key still reaches the emoji.
struct EmojiKeyboardField: UIViewRepresentable {
    @Binding var isActive: Bool
    let onPick: (String) -> Void

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.delegate = context.coordinator
        field.tintColor = .clear
        field.autocorrectionType = .no
        return field
    }

    func updateUIView(_ field: EmojiTextField, context: Context) {
        context.coordinator.parent = self
        // After this update, so a field just added to the window can take focus.
        Task { @MainActor in
            if isActive, !field.isFirstResponder {
                field.becomeFirstResponder()
            } else if !isActive, field.isFirstResponder {
                field.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// One emoji, as a single character; the rules cap a reaction at 16 characters.
    static func emoji(in text: String) -> String? {
        guard text.count == 1, let character = text.first, text.unicodeScalars.count <= 16 else { return nil }
        let scalars = character.unicodeScalars
        let isEmoji = scalars.contains { $0.properties.isEmojiPresentation }
            || (scalars.count > 1 && scalars.first?.properties.isEmoji == true)
        return isEmoji ? text : nil
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiKeyboardField

        init(parent: EmojiKeyboardField) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if let emoji = EmojiKeyboardField.emoji(in: string) {
                parent.onPick(emoji)
            }
            return false
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isActive { parent.isActive = false }
        }
    }
}

final class EmojiTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }
}
