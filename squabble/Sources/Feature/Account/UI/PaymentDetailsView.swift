import FactoryKit
import SwiftUI

/// Pushed from the account screen: the payment slip as a preview, the saved methods with a
/// way to remove them, and tiles to add more. Every change is saved straight away.
struct PaymentDetailsView: View {
    @Environment(AuthSession.self) private var session
    @State private var methods: [PaymentMethod]?
    @State private var editing: PaymentMethodEditor.Kind?
    @State private var failure: String?

    @Injected(\.profileRepository) private var profiles

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let methods {
                    content(methods)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(Text("Payment details"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: session.user?.id) { await observe() }
        .sheet(item: $editing) { kind in
            PaymentMethodEditor(kind: kind, defaultHolderName: session.profile?.displayName ?? "") { method in
                save((methods ?? []) + [method])
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: failure ?? "")
        }
    }

    @ViewBuilder
    private func content(_ methods: [PaymentMethod]) -> some View {
        PaymentSlipView(name: session.profile?.displayName ?? "", methods: methods)
            .padding(.horizontal, 4)
        if methods.count < PaymentMethod.maxCount {
            PaymentMethodTiles { editing = $0 }
        }
        if methods.isEmpty {
            Text(
                "Nothing here yet. Bold of you to expect people to pay you back by telepathy.",
                comment: "Payment details page: empty state."
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
        } else {
            VStack(spacing: 12) {
                ForEach(methods) { method in
                    PaymentMethodRow(method: method) {
                        save(methods.filter { $0.id != method.id })
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            Label("Only people you split bills with can see these.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func observe() async {
        guard let uid = session.user?.id else { return }
        do {
            for try await methods in profiles.paymentMethodChanges(for: uid) {
                withAnimation { self.methods = methods }
            }
        } catch {
            guard !Task.isCancelled else { return }
            AppLog.error(error, "Payment methods listener failed")
            failure = error.localizedDescription
        }
    }

    private func save(_ updated: [PaymentMethod]) {
        guard let uid = session.user?.id else { return }
        do {
            try profiles.setPaymentMethods(updated, for: uid)
            withAnimation { methods = updated }
        } catch {
            failure = error.localizedDescription
        }
    }
}
