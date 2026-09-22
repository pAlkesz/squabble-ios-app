import SwiftUI

/// The welcome screen's centrepiece: a receipt that feeds out of an unseen printer,
/// then sways to a stop. Reduce Motion gets the finished receipt with a plain fade.
struct WelcomeReceiptView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLaunchSplashFinished) private var isLaunchSplashFinished
    @State private var unfurl: CGFloat = 0
    @State private var sway = Angle.degrees(-2.5)

    var body: some View {
        paper
            .mask(alignment: .top) {
                GeometryReader { proxy in
                    Rectangle().frame(height: proxy.size.height * unfurl)
                }
            }
            .rotationEffect(sway, anchor: .top)
            .opacity(reduceMotion ? Double(unfurl) : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(
                "A joke receipt: nachos, Dave's third beer, emotional damage. Total: friendship.",
                comment: "VoiceOver description of the decorative welcome-screen receipt."
            ))
            .task(id: isLaunchSplashFinished, print)
    }

    private var paper: some View {
        VStack(spacing: 7) {
            ForEach(Array(WelcomeReceipt.rows.enumerated()), id: \.offset) { _, row in
                self.row(row)
            }
        }
        .foregroundStyle(Color.receiptInk)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background {
            TornPaperShape()
                .fill(Color.receiptPaper)
                .shadow(color: .black.opacity(0.55), radius: 20, x: 0, y: 12)
        }
    }

    @ViewBuilder
    private func row(_ row: ReceiptRow) -> some View {
        switch row {
        case .header(let text):
            Text(text)
                .font(.system(.headline, design: .monospaced, weight: .heavy))
                .kerning(4)
        case .subheader(let text):
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .opacity(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .rule:
            DottedLeader().opacity(0.5)
        case .item(let label, let amount):
            HStack(alignment: .bottom, spacing: 6) {
                Text(label)
                DottedLeader().opacity(0.4)
                Text(amount)
            }
            .font(.system(.caption, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        case .note(let text):
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .italic()
                .opacity(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
        case .total(let label, let amount):
            HStack(alignment: .bottom, spacing: 6) {
                Text(label)
                DottedLeader().opacity(0.4)
                Text(amount)
            }
            .font(.system(.caption, design: .monospaced, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        case .footer(let text):
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .opacity(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    @Sendable
    private func print() async {
        guard isLaunchSplashFinished, unfurl == 0 else { return }
        guard !reduceMotion else {
            withAnimation(.easeIn(duration: 0.4)) { unfurl = 1 }
            sway = .zero
            return
        }
        withAnimation(.easeOut(duration: 1.5)) { unfurl = 1 }
        try? await Task.sleep(for: .seconds(0.55))
        withAnimation(.spring(response: 1.1, dampingFraction: 0.32)) { sway = .zero }
    }
}

#Preview {
    ZStack {
        SquabbleBackdrop()
        WelcomeReceiptView().padding(32)
    }
}
