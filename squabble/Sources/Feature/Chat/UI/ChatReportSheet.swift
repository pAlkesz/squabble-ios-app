import SwiftUI

/// Opened from Report in a message's long-press menu: pick what's wrong with it, then send.
/// Nothing is written until Send report.
struct ChatReportSheet: View {
    let onReport: (ChatReportReason) -> Void

    @State private var reason: ChatReportReason?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What's wrong with this message?", comment: "Report sheet: question above the list of reasons.")
                        .font(.headline)
                        .padding(.horizontal, 4)
                    VStack(spacing: 0) {
                        ForEach(ChatReportReason.allCases) { reason in
                            row(reason)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
                    Text("We'll take a look. The author won't know it was you.", comment: "Report sheet: note under the reasons.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                }
                .padding(16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationTitle(Text("Report message", comment: "Report sheet: title."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) { sendButton }
        }
        .foregroundStyle(.white)
        .presentationDetents([.large])
        .presentationBackground { ProfileBackdrop() }
        .sensoryFeedback(.selection, trigger: reason)
    }

    private func row(_ reason: ChatReportReason) -> some View {
        let isSelected = reason == self.reason
        return Button {
            self.reason = reason
        } label: {
            HStack(spacing: 14) {
                Image(systemName: reason.systemImage)
                    .frame(width: 28)
                Text(reason.title)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.white : .white.opacity(0.35))
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var sendButton: some View {
        Button {
            guard let reason else { return }
            onReport(reason)
            dismiss()
        } label: {
            Text("Send report", comment: "Report sheet: button that sends the report.")
        }
        .buttonStyle(.squabblePrimary)
        .disabled(reason == nil)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: 560)
    }
}
