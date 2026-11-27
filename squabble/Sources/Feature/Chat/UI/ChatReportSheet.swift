import SwiftUI

/// Opened from Report in a message's long-press menu: pick what's wrong with it, then send.
/// Nothing is written until Send report.
struct ChatReportSheet: View {
    let onReport: (ChatReportReason) -> Void

    @State private var reason: ChatReportReason?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // A native section, so the question and the note sit where iOS puts a header and
            // a footer, as in the app's other lists.
            List {
                Section {
                    ForEach(ChatReportReason.allCases) { reason in
                        row(reason)
                            // The account screen's cards: the system's grey rows read as a
                            // different surface on these backdrops.
                            .listRowBackground(Color.white.opacity(0.08))
                            .listRowSeparatorTint(.white.opacity(0.12))
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                } header: {
                    Text("What's wrong with this message?", comment: "Report sheet: question above the list of reasons.")
                } footer: {
                    Text("We'll take a look. The author won't know it was you.", comment: "Report sheet: note under the reasons.")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
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
                    .font(.body.weight(.medium))
                    .frame(width: 22)
                Text(reason.title)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.white : .white.opacity(0.35))
            }
            .frame(minHeight: 54)
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
