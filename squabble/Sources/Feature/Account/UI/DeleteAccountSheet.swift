import AuthenticationServices
import SwiftUI

/// The last step of deleting an account: what's about to go, then Sign in with Apple to
/// confirm. Firebase only deletes an account after a fresh sign-in, and the authorization
/// code it hands back is what revokes Squabble's access at Apple.
struct DeleteAccountSheet: View {
    let isDeleting: Bool
    let onConfirm: (Result<AppleSignInResult, Error>) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.red.opacity(0.85), in: .circle)
                    .padding(.bottom, 4)
                Text("Last chance", comment: "Delete account sheet: title.")
                    .font(.title2.bold())
                Text(
                    "Confirm with Apple and your profile, payment details and photos are gone for good. No undo — not even we can bring them back.",
                    comment: "Delete account sheet: description above the Apple button."
                )
                .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                ZStack {
                    AppleSignInButton(label: .continue, onCompletion: onConfirm)
                        .opacity(isDeleting ? 0 : 1)
                    if isDeleting {
                        ProgressView().tint(.white)
                    }
                }
                .frame(height: 50)
                .disabled(isDeleting)
                Button {
                    dismiss()
                } label: {
                    Text("Never mind", comment: "Delete account sheet: button that closes it without deleting.")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.8))
                .disabled(isDeleting)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 8)
        .frame(maxWidth: 480)
        .interactiveDismissDisabled(isDeleting)
        .fittedSheet()
    }
}
