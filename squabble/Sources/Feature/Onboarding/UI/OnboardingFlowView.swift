import FactoryKit
import SwiftUI

/// Sign-in and first-run onboarding as one native navigation stack: sign-in is the root
/// and each onboarding step is pushed on top. Popping back to the root (back button or
/// swipe) signs out, since a signed-in user without a profile can't stay on sign-in.
/// Nothing is written until the last step; once the profile exists, `AuthSession`
/// notices and the root swaps to home on its own.
struct OnboardingFlowView: View {
    @Environment(AuthSession.self) private var session
    @Injected(\.profileRepository) private var profiles
    @Injected(\.avatarStore) private var avatars

    @State private var path: [OnboardingStep] = []
    @State private var draft: OnboardingDraft?
    @State private var handleAvailability: HandleAvailability = .idle
    @State private var isSubmitting = false
    @State private var failure: OnboardingFailure?

    var body: some View {
        NavigationStack(path: $path) {
            SignInView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: OnboardingStep.self, destination: page)
        }
        .onChange(of: session.state, initial: true) { previous, state in
            sync(with: state, animated: previous != state)
        }
        .onChange(of: path) {
            if path.isEmpty, case .needsOnboarding = session.state {
                try? session.signOut()
            }
        }
        .task(id: draft?.handle) { await checkHandle() }
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
    private func page(for step: OnboardingStep) -> some View {
        if let draft = Binding($draft) {
            OnboardingPage(
                step: step,
                primaryTitle: primaryTitle(for: step),
                canContinue: canContinue(from: step),
                isSubmitting: isSubmitting
            ) {
                advance(from: step)
            } content: {
                switch step {
                case .name:
                    OnboardingNameStep(draft: draft, availability: handleAvailability)
                case .avatar:
                    OnboardingAvatarStep(draft: draft) { error in
                        failure = OnboardingFailure(message: error.localizedDescription)
                    }
                case .payment:
                    OnboardingPaymentStep(draft: draft)
                }
            }
        }
    }

    private func sync(with state: AuthSession.State, animated: Bool) {
        switch state {
        case .needsOnboarding(let user):
            guard path.isEmpty else { return }
            draft = OnboardingDraft(user: user)
            handleAvailability = .idle
            // Relaunching mid-onboarding lands on the first step directly, without a push.
            var transaction = Transaction()
            transaction.disablesAnimations = !animated
            withTransaction(transaction) { path = [.name] }
        case .signedOut:
            // The draft stays until the next sign-in replaces it: the popped page still
            // renders through its binding while it animates away.
            path = []
        case .loading, .profileUnavailable, .signedIn:
            break
        }
    }

    private func primaryTitle(for step: OnboardingStep) -> LocalizedStringKey {
        switch step {
        case .name, .avatar: "Continue"
        case .payment: draft?.paymentMethods.isEmpty ?? true ? "Skip for now" : "Finish"
        }
    }

    private func canContinue(from step: OnboardingStep) -> Bool {
        switch step {
        case .name:
            guard let draft, draft.validDisplayName != nil, case .success = draft.validatedHandle else { return false }
            return !handleAvailability.blocksContinuing
        case .avatar, .payment:
            return true
        }
    }

    private func advance(from step: OnboardingStep) {
        if let next = step.next {
            path.append(next)
        } else {
            Task { await finish() }
        }
    }

    private func checkHandle() async {
        guard let draft, !draft.handle.isEmpty else {
            handleAvailability = .idle
            return
        }
        switch draft.validatedHandle {
        case .failure(let error):
            handleAvailability = .invalid(error)
        case .success(let handle):
            handleAvailability = .checking
            // Debounce: `task(id:)` cancels this sleep on every keystroke.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let uid = session.user?.id else { return }
            do {
                let isAvailable = try await profiles.isHandleAvailable(handle, for: uid)
                guard !Task.isCancelled else { return }
                handleAvailability = isAvailable ? .available : .taken
            } catch {
                guard !Task.isCancelled else { return }
                handleAvailability = .unknown
            }
        }
    }

    private func finish() async {
        guard let uid = session.user?.id, let current = draft else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if let jpeg = current.photoJPEG, current.uploadedPhoto == nil {
                draft?.uploadedPhoto = try await avatars.upload(jpeg, for: uid)
            }
            guard let profile = draft?.profile(for: uid), let methods = draft?.paymentMethods else {
                path = [.name]
                return
            }
            try await profiles.createProfile(profile, paymentMethods: methods)
        } catch ProfileError.handleTaken {
            handleAvailability = .taken
            path = [.name]
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
