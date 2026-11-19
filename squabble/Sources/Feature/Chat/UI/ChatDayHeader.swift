import SwiftUI

/// "Today", "Tue", "Sep 30" between messages from different days.
struct ChatDayHeader: View {
    let day: Date

    var body: some View {
        Text(verbatim: ChatTimeline.dayTitle(for: day))
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .accessibilityAddTraits(.isHeader)
    }
}
