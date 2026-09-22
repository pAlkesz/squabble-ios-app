import FactoryKit
import SwiftUI

/// First-run profile setup: name and handle, avatar, then optional payment details.
/// Nothing is written until the last step; once the profile exists, `AuthSession`
/// notices and the root swaps to home on its own.
struct OnboardingView: View {
    let user: AppUser

    @Environment(AuthSession.self) private var session
    @Injected(\.profileRepository) private var profiles
    @Injected(\.avatarStore) private var avatars

    @State private var draft: OnboardingDraft
    @State private var step: OnboardingStep = .name
    @State private var handleAvailability: HandleAvailability = .idle
    @State private var isSubmitting = false
    @State private var failure: OnboardingFailure?

    init(user: AppUser) {
        self.user = user
        _draft = State(initialValue: OnboardingDraft(user: user))
    }

    var body: some View {
        ZStack {
            SquabbleBackdrop()
            VStack(spacing: 0) {
                header
                ScrollView {
                    stepContent
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                footer
            }
        }
        .foregroundStyle(.white)
        .disabled(isSubmitting)
        .task(id: draft.handle) { await checkHandle() }
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

    private var header: some View {
        HStack {
            if let previous = step.previous {
                Button("Back", systemImage: "chevron.left") {
                    withAnimation(.snappy) { step = previous }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
            } else {
                Button("Sign out") { try? session.signOut() }
                    .buttonStyle(.glass)
            }
            Spacer()
            progress
            Spacer()
            // Mirrors the leading button's width so the progress stays centred.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(.white.opacity(item <= step ? 1 : 0.3))
                    .frame(width: item == step ? 28 : 8, height: 8)
            }
        }
        .animation(.snappy, value: step)
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)"))
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch step {
            case .name:
                OnboardingNameStep(draft: $draft, availability: handleAvailability)
            case .avatar:
                OnboardingAvatarStep(draft: $draft) { error in
                    failure = OnboardingFailure(message: error.localizedDescription)
                }
            case .payment:
                OnboardingPaymentStep(draft: $draft)
            }
        }
        .id(step)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var footer: some View {
        Button(action: advance) {
            Group {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text(primaryTitle)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .disabled(!canContinue)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
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
            return !handleAvailability.blocksContinuing
        case .avatar, .payment:
            return true
        }
    }

    private func advance() {
        if let next = step.next {
            withAnimation(.snappy) { step = next }
        } else {
            Task { await finish() }
        }
    }

    private func checkHandle() async {
        guard !draft.handle.isEmpty else {
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
            guard !Task.isCancelled else { return }
            do {
                let isAvailable = try await profiles.isHandleAvailable(handle, for: user.id)
                guard !Task.isCancelled else { return }
                handleAvailability = isAvailable ? .available : .taken
            } catch {
                guard !Task.isCancelled else { return }
                handleAvailability = .unknown
            }
        }
    }

    private func finish() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            if let jpeg = draft.photoJPEG, draft.uploadedPhoto == nil {
                draft.uploadedPhoto = try await avatars.upload(jpeg, for: user.id)
            }
            guard let profile = draft.profile(for: user.id) else {
                withAnimation(.snappy) { step = .name }
                return
            }
            try await profiles.createProfile(profile, paymentMethods: draft.paymentMethods)
        } catch ProfileError.handleTaken {
            handleAvailability = .taken
            withAnimation(.snappy) { step = .name }
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
