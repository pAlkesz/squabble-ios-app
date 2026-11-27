import SwiftUI

/// What a chat shows while its messages are on their way: the bird hopping on the spot
/// (`HoppingBirdView`). It fades in only after a moment, so a chat the cache answers at once
/// never flashes it, and owns up when the wait drags on.
struct ChatLoadingView: View {
    let isTakingLong: Bool
    /// Once it's actually visible, so the timeline knows to fade in rather than just appear.
    let onShown: () -> Void

    @State private var isShown = false

    private static let delay: Duration = .milliseconds(300)

    var body: some View {
        VStack(spacing: 14) {
            HoppingBirdView()
                .frame(width: 84)
            if isTakingLong {
                Text("Taking its time. Bad signal, or the messages are just shy.", comment: "Chat: under the spinner when the messages take more than a couple of seconds to arrive.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .padding(32)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isShown ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: isShown)
        .animation(.easeOut(duration: 0.25), value: isTakingLong)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Loading messages", comment: "Chat: VoiceOver label of the spinner shown while the messages load."))
        .task {
            try? await Task.sleep(for: Self.delay)
            guard !Task.isCancelled else { return }
            isShown = true
            onShown()
        }
    }
}
