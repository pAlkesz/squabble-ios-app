import SwiftUI

/// A labelled input sitting on the backdrop: title above, a frosted well for the control,
/// and an optional one-line message underneath (a hint, or what's wrong).
struct SquabbleField<Content: View>: View {
    let title: LocalizedStringKey
    var message: SquabbleFieldMessage?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            content
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(.white.opacity(0.12), in: .rect(cornerRadius: 16))
            if let message {
                Text(message.text)
                    .font(.footnote)
                    .foregroundStyle(color(for: message.tone))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: message)
    }

    private func color(for tone: SquabbleFieldMessage.Tone) -> Color {
        switch tone {
        case .hint: .white.opacity(0.65)
        case .success: .white
        case .problem: .red
        }
    }
}
