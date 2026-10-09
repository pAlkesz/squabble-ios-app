import SwiftUI

/// Renders a `SquabbleFieldMessage` as a section footer.
struct FieldMessageFooter: View {
    let message: SquabbleFieldMessage?

    var body: some View {
        if let message {
            if let color = message.color {
                Text(message.text).foregroundStyle(color)
            } else {
                Text(message.text)
            }
        }
    }
}
