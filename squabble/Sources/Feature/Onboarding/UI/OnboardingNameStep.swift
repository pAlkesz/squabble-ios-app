import SwiftUI

struct OnboardingNameStep: View {
    @Binding var draft: OnboardingDraft
    let availability: HandleAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            OnboardingHeading(
                title: "What do we call you?",
                subtitle: "This is the name on every bill — and on every reminder that you're owed money."
            )
            SquabbleField(title: "Display name", message: nameMessage) {
                TextField(
                    "Your name",
                    text: Binding(get: { draft.displayName }, set: { draft.setDisplayName($0) })
                )
                .textContentType(.name)
                .submitLabel(.next)
            }
            SquabbleField(title: "Handle", message: handleMessage) {
                HStack(spacing: 2) {
                    Text(verbatim: "@")
                        .foregroundStyle(.white.opacity(0.6))
                    TextField(
                        "handle",
                        text: Binding(get: { draft.handle }, set: { draft.setHandle($0) })
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    if availability == .checking {
                        ProgressView().tint(.white)
                    } else if availability == .available {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private var nameMessage: SquabbleFieldMessage {
        if draft.displayName.count > UserProfile.maxDisplayNameLength {
            return .init(text: String(localized: "40 characters max. It has to fit on a receipt."), tone: .problem)
        }
        return .init(text: String(localized: "Doesn't have to be unique. Your friends know who you are."), tone: .hint)
    }

    private var handleMessage: SquabbleFieldMessage {
        switch availability {
        case .idle, .checking:
            .init(text: String(localized: "Unique. It's how people find you."), tone: .hint)
        case .available:
            .init(text: String(localized: "Nice, it's all yours."), tone: .success)
        case .taken:
            .init(text: String(localized: "Taken. Someone got there first."), tone: .problem)
        case .unknown:
            .init(text: String(localized: "Can't check right now. We'll make sure when you finish."), tone: .hint)
        case .invalid(let error):
            .init(text: error.localizedDescription, tone: .problem)
        }
    }
}
