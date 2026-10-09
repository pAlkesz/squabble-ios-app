import FactoryKit
import SwiftUI

/// First-run profile setup as one screen with a pager: name and handle, avatar, then
/// optional payment methods. The traffic-light backdrop, the progress segments and the
/// primary button stay put; only the page content slides. The pager is driven by the
/// buttons alone — there's no swipe, so the handle can't be skipped past. It's an offset
/// row of pages rather than a paging `ScrollView`: scroll content doesn't receive the
/// keyboard's safe area, so forms there scrolled their footers under the keyboard.
/// Nothing is written until the last page; once the profile exists, `AuthSession`
/// notices and the root swaps to home on its own.
struct OnboardingView: View {
    let user: AppUser

    @Injected(\.profileRepository) private var profiles
    @Injected(\.avatarStore) private var avatars
    @Injected(\.connectivityMonitor) private var connectivity

    @State private var draft: OnboardingDraft
    @State private var step: OnboardingStep = .name
    @State private var handleAvailability: HandleAvailability = .idle
    @State private var handleSuggestions: [Handle] = []
    @State private var isOnline = true
    // Relaunching mid-onboarding mounts this behind the launch splash. Its lookups wait
    // for the splash to go: their answers restyle the name fields, and landing during
    // the fly-away that stutters the bird.
    @Environment(\.isLaunchSplashFinished) private var isLaunchSplashFinished
    @State private var handleCheckAttempt = 0
    @State private var isSubmitting = false
    @State private var failure: OnboardingFailure?
    @State private var pageWidth: CGFloat = 0

    init(user: AppUser) {
        self.user = user
        _draft = State(initialValue: OnboardingDraft(user: user))
    }

    var body: some View {
        // Every page gets the same full frame, shifted by whole page widths; that keeps
        // their layout and safe areas (keyboard included) completely standard.
        ZStack {
            ForEach(OnboardingStep.allCases, id: \.self) { page in
                content(for: page)
                    .offset(x: CGFloat(page.rawValue - step.rawValue) * pageWidth)
                    .allowsHitTesting(page == step)
                    .accessibilityHidden(page != step)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
        // A safe-area bar rather than an overlay: pages scroll clear of the button, and
        // content passing under it gets the system scroll edge effect, as under the top bar.
        .safeAreaBar(edge: .bottom) { primaryButton }
        .background { OnboardingBackdrop(step: step) }
        .containerBackground(.clear, for: .navigation)
        .tint(.white)
        .disabled(isSubmitting)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let previous = step.previous {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") { go(to: previous) }
                }
            }
            ToolbarItem(placement: .principal) {
                OnboardingProgressSegments(step: step)
                    .frame(width: 220)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .task {
            for await isOnline in connectivity.updates() {
                self.isOnline = isOnline
            }
        }
        // Suggestions follow the display name, so typing a handle doesn't cost lookups.
        .task(id: SuggestionKey(name: draft.displayName, isOnline: isOnline, isVisible: isLaunchSplashFinished)) {
            await loadSuggestions()
        }
        // Re-checks on every edit, when the connection comes back, and on "Try again".
        .task(id: HandleCheckKey(
            handle: draft.handle,
            isOnline: isOnline,
            attempt: handleCheckAttempt,
            isVisible: isLaunchSplashFinished
        )) {
            await checkHandle()
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }),
            presenting: failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
    }

    @ViewBuilder
    private func content(for page: OnboardingStep) -> some View {
        switch page {
        case .name:
            OnboardingNameStep(
                draft: $draft,
                availability: handleAvailability,
                suggestions: handleSuggestions,
                isCurrent: step == .name
            ) {
                handleCheckAttempt += 1
            }
        case .avatar:
            OnboardingPage {
                OnboardingAvatarStep(draft: $draft) { error in
                    failure = OnboardingFailure(message: error.localizedDescription)
                }
            }
        case .payment:
            OnboardingPage {
                OnboardingPaymentStep(draft: $draft)
            }
        }
    }

    private var primaryButton: some View {
        Button(action: advance) {
            if isSubmitting {
                ProgressView().tint(.backdropDeep)
            } else {
                Text(primaryTitle)
            }
        }
        .buttonStyle(.squabblePrimary)
        .disabled(!canContinue || isSubmitting)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        // Keeps clear air between the button and the keyboard when it's up.
        .padding(.bottom, 20)
        .frame(maxWidth: 560)
    }

    private var primaryTitle: LocalizedStringKey {
        switch step {
        case .name, .avatar: "Continue"
        case .payment: draft.paymentMethods.isEmpty ? "Skip for now" : "Finish"
        }
    }

    private var canContinue: Bool {
        switch step {
        case .name:
            guard draft.validDisplayName != nil, case .success = draft.validatedHandle else { return false }
            return handleAvailability.allowsContinuing
        case .avatar, .payment:
            return true
        }
    }

    private func advance() {
        if let next = step.next {
            go(to: next)
        } else {
            Task { await finish() }
        }
    }

    private func go(to page: OnboardingStep) {
        withAnimation(.smooth(duration: 0.45)) {
            step = page
        }
    }

    private func checkHandle() async {
        guard isLaunchSplashFinished else { return }
        if let verdict = HandleAvailabilityChecker.preflight(draft.handle, isOnline: isOnline) {
            handleAvailability = verdict
            return
        }
        handleAvailability = .checking
        // Debounce: `task(id:)` cancels this sleep on every keystroke.
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        let checker = HandleAvailabilityChecker(profiles: profiles)
        let result = await checker.check(draft.handle, for: user.id, isOnline: true)
        guard !Task.isCancelled else { return }
        handleAvailability = result
    }

    private func loadSuggestions() async {
        guard isLaunchSplashFinished else { return }
        let candidates = HandleSuggestions.candidates(fromName: draft.displayName)
        guard isOnline, !candidates.isEmpty else {
            handleSuggestions = []
            return
        }
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        // One spare, since whichever matches the typed handle is hidden.
        let free = await HandleAvailabilityChecker(profiles: profiles)
            .freeHandles(among: candidates, uid: user.id, limit: OnboardingNameStep.suggestionCount + 1)
        guard !Task.isCancelled else { return }
        withAnimation { handleSuggestions = free }
    }

    private func finish() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if let jpeg = draft.photoToUpload {
                draft.uploadedPhoto = try await avatars.upload(jpeg, for: user.id)
            }
            guard let profile = draft.profile(for: user.id) else {
                go(to: .name)
                return
            }
            try await profiles.createProfile(profile, paymentMethods: draft.paymentMethods)
        } catch ProfileError.handleTaken {
            handleAvailability = .taken
            go(to: .name)
            failure = OnboardingFailure(message: ProfileError.handleTaken.localizedDescription)
        } catch {
            AppLog.error(error, "Onboarding save failed")
            failure = OnboardingFailure(message: error.localizedDescription)
        }
    }
}

private struct OnboardingFailure: Identifiable {
    let id = UUID()
    let message: String
}

private struct HandleCheckKey: Equatable {
    let handle: String
    let isOnline: Bool
    let attempt: Int
    let isVisible: Bool
}

private struct SuggestionKey: Equatable {
    let name: String
    let isOnline: Bool
    let isVisible: Bool
}
