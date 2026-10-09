import SwiftUI

/// The name page: a native form, with the page heading as its first, backgroundless row.
/// The handle check gets a reaction — the bird in the section header nods or shakes its
/// head, the field shakes (and turns red when taken) and a haptic plays. Under the field
/// sit the note with a character counter, then free handles based on the display name
/// as chips.
struct OnboardingNameStep: View {
    @Binding var draft: OnboardingDraft
    let availability: HandleAvailability
    /// Free handles based on the display name; whichever equals the typed one is hidden.
    let suggestions: [Handle]

    static let suggestionCount = 3
    /// Clears the keyboard when the pager moves on, since the page stays alive offscreen.
    let isCurrent: Bool
    let onRetry: () -> Void

    private enum Field: Hashable {
        case name
        case handle
    }

    @FocusState private var focusedField: Field?
    @State private var availableCount = 0
    @State private var takenCount = 0
    @State private var retryCount = 0
    // The fields edit local copies, and only the capped value reaches the draft. Binding
    // them straight to the draft either left extra characters on screen (a capped value
    // equal to the stored one doesn't redraw the field) or briefly stored the over-long
    // value, flashing the counter and firing a handle check.
    @State private var nameText: String
    @State private var handleText: String

    init(
        draft: Binding<OnboardingDraft>,
        availability: HandleAvailability,
        suggestions: [Handle],
        isCurrent: Bool,
        onRetry: @escaping () -> Void
    ) {
        _draft = draft
        self.availability = availability
        self.suggestions = suggestions
        self.isCurrent = isCurrent
        self.onRetry = onRetry
        _nameText = State(initialValue: draft.wrappedValue.displayName)
        _handleText = State(initialValue: draft.wrappedValue.handle)
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // While typing, the pinned Continue button and the keyboard cover the bottom of the
        // page, where the focused field's footer — the reason Continue may be disabled — is
        // written. Scrolling the focused row towards the top brings its footer up; the page
        // is short, so the form simply scrolls as far as it can. Forms only honour
        // row-targeted scrolling, and the keyboard arrives as a content-inset change, so
        // that's the trigger alongside focus and message changes.
        ScrollViewReader { proxy in
            form
                .onChange(of: focusedField) { reveal(with: proxy) }
                .onChange(of: availability) { reveal(with: proxy) }
                // Suggestions arrive on their own schedule and change the page's height.
                .onChange(of: suggestions) { reveal(with: proxy) }
                .onChange(of: nameMessage) { reveal(with: proxy) }
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentInsets.bottom } action: { _, _ in
                    reveal(with: proxy)
                }
        }
        .onChange(of: isCurrent) {
            if !isCurrent { focusedField = nil }
        }
        .onChange(of: nameText) {
            let capped = String(nameText.prefix(UserProfile.maxDisplayNameLength))
            if capped != nameText {
                nameText = capped
            } else if capped != draft.displayName {
                draft.setDisplayName(capped)
            }
        }
        .onChange(of: handleText) {
            let capped = String(handleText.prefix(Handle.lengthRange.upperBound))
            if capped != handleText {
                handleText = capped
            } else if capped != draft.handle {
                draft.setHandle(capped)
            }
        }
        // The handle also changes from outside the field: a tapped suggestion, or the
        // display name while the handle hasn't been edited.
        .onChange(of: draft.handle) {
            if handleText != draft.handle { handleText = draft.handle }
        }
        .onChange(of: availability) {
            switch availability {
            case .available: availableCount += 1
            case .taken: takenCount += 1
            default: break
            }
        }
        .sensoryFeedback(.success, trigger: availableCount)
        .sensoryFeedback(.error, trigger: takenCount)
    }

    private var form: some View {
        Form {
            Section {
                OnboardingHeading(
                    title: "What do we call you?",
                    subtitle: "This is the name on every bill — and on every reminder that you're owed money."
                )
                // Aligned with the section headers below; zero insets clip the glyphs' edges.
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            Section {
                TextField(
                    "Your name",
                    text: $nameText
                )
                .textContentType(.name)
                .submitLabel(.next)
                .onSubmit { focusedField = .handle }
                .focused($focusedField, equals: .name)
                .id(Field.name)
                .listRowBackground(nameMessage.tone == .problem ? Color.red.opacity(0.22) : nil)
            } header: {
                Text("Display name")
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    FieldMessageFooter(message: nameMessage)
                    Spacer(minLength: 12)
                    Text("\(draft.displayName.count)/\(UserProfile.maxDisplayNameLength)")
                        .monospacedDigit()
                        .foregroundStyle(nameMessage.tone == .problem ? Color.red : Color.secondary)
                }
            }
            Section {
                handleRow
                    .id(Field.handle)
                    .listRowBackground(handleMessage.tone == .problem ? Color.red.opacity(0.22) : nil)
            } header: {
                HStack(alignment: .bottom) {
                    Text("Handle")
                    Spacer()
                    // Perched on the field it's watching.
                    ReactingBirdView(nodTrigger: availableCount, shakeTrigger: takenCount)
                        .frame(width: 44)
                        .padding(.bottom, -6)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        FieldMessageFooter(message: handleMessage)
                        Spacer(minLength: 12)
                        Text("\(draft.handle.count)/\(Handle.lengthRange.upperBound)")
                            .monospacedDigit()
                            .foregroundStyle(handleMessage.tone == .problem ? Color.red : Color.secondary)
                    }
                    if !visibleSuggestions.isEmpty {
                        suggestionChips
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        // Grouped forms leave a tall gap above the first section; the heading row should
        // sit right under the progress bar instead.
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        .animation(.default, value: availability)
    }

    private func reveal(with proxy: ScrollViewProxy) {
        // A taken handle's message and suggestions sit lowest on the page; on shorter
        // screens they'd be behind the button even without the keyboard.
        guard let target = focusedField ?? (availability == .taken ? .handle : nil) else { return }
        withAnimation { proxy.scrollTo(target, anchor: .top) }
    }

    private var handleRow: some View {
        // Captured up front: keyframe closures are Sendable and can't read the environment.
        let isStill = reduceMotion
        return HStack(spacing: 2) {
            Text(verbatim: "@")
                .foregroundStyle(.secondary)
            TextField(
                "handle",
                text: $handleText
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .focused($focusedField, equals: .handle)
            if availability == .checking {
                ProgressView()
            } else if availability == .available {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: availableCount)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            } else if availability == .failed {
                // Where a clear button would sit: a failed check is retried from the field
                // itself rather than a separate row.
                Button("Try again", systemImage: "arrow.clockwise") {
                    retryCount += 1
                    onRetry()
                }
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .symbolEffect(.rotate, value: retryCount)
                // Borderless, or the whole row becomes the button and swallows taps meant
                // for the text field.
                .buttonStyle(.borderless)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .keyframeAnimator(initialValue: CGFloat.zero, trigger: takenCount) { content, offset in
            content.offset(x: isStill ? 0 : offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-8, duration: 0.06)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-5, duration: 0.08)
                LinearKeyframe(3, duration: 0.07)
                LinearKeyframe(0, duration: 0.06)
            }
        }
    }

    private var visibleSuggestions: [Handle] {
        let typed = draft.handle.lowercased()
        return Array(suggestions.filter { $0.rawValue != typed }.prefix(Self.suggestionCount))
    }

    private var suggestionChips: some View {
        // Wraps rather than scrolls, so every suggestion is visible at once.
        FlowLayout {
            ForEach(visibleSuggestions, id: \.self) { suggestion in
                Button {
                    draft.setHandle(suggestion.rawValue)
                } label: {
                    Text(verbatim: suggestion.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.fill.secondary, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Every reason Continue can be disabled shows up in a footer, never silently.
    private var nameMessage: SquabbleFieldMessage {
        if draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .init(text: String(localized: "Tell us what to call you."), tone: .problem)
        }
        if draft.displayName.count > UserProfile.maxDisplayNameLength {
            return .init(text: String(localized: "50 characters max. It has to fit on a receipt."), tone: .problem)
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
        case .offline:
            .init(text: String(localized: "You're offline. Connect to the internet so we can check this handle."), tone: .problem)
        case .failed:
            .init(text: String(localized: "Couldn't check this handle. Tap the arrow to try again."), tone: .problem)
        case .invalid(let error):
            .init(text: error.localizedDescription, tone: .problem)
        }
    }
}
