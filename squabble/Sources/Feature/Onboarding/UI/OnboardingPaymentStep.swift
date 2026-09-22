import SwiftUI

struct OnboardingPaymentStep: View {
    @Binding var draft: OnboardingDraft
    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            OnboardingHeading(
                title: "Where should the money go?",
                subtitle: "Optional. Add a bank account or a payment link, and “I didn’t know how to pay you” stops being an excuse."
            )
            VStack(spacing: 12) {
                ForEach(draft.paymentMethods) { method in
                    PaymentMethodRow(method: method) {
                        withAnimation { draft.paymentMethods.removeAll { $0.id == method.id } }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                if draft.canAddPaymentMethod {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add a way to pay you", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }
            }
            Label("Only people you split bills with can see these. You can change them any time.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .sheet(isPresented: $isAdding) {
            PaymentMethodEditor(defaultHolderName: draft.validDisplayName ?? "") { method in
                withAnimation { draft.paymentMethods.append(method) }
            }
        }
    }
}
