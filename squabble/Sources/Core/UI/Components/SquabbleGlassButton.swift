import SwiftUI

/// Full-width glass button for sheets. `.prominent` is the one action the sheet exists
/// for — white with black text, since the sheets sit on green; everything else is clear
/// glass. `isLoading` swaps the label for a spinner without changing the button's size.
struct SquabbleGlassButton: View {
    enum Kind {
        case prominent
        case clear
    }

    let title: LocalizedStringResource
    var systemImage: String?
    var kind: Kind = .clear
    var isLoading = false
    let action: () -> Void

    var body: some View {
        styled(
            Button(action: action) {
                ZStack {
                    label
                        .bold()
                        .opacity(isLoading ? 0 : 1)
                    if isLoading {
                        ProgressView()
                            .tint(kind == .prominent ? .black : .white)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .disabled(isLoading)
        )
    }

    @ViewBuilder
    private var label: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }

    @ViewBuilder
    private func styled(_ button: some View) -> some View {
        switch kind {
        case .prominent:
            button
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)
        case .clear:
            button
                .buttonStyle(.glass(.clear))
        }
    }
}
