import SwiftUI

/// Pushed from the account screen. Saving pops back; the name shows up there straight
/// from the local cache, even offline.
struct DisplayNameEditView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var failure: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Your name", text: $name)
                .textContentType(.name)
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit(save)
                .onChange(of: name) { _, typed in
                    let capped = String(typed.prefix(UserProfile.maxDisplayNameLength))
                    if capped != typed { name = capped }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
            Text(
                "This is what shows up on receipts and reminders. Your handle stays the same.",
                comment: "Display name editor: footnote under the field."
            )
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 4)
        }
        .padding(16)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
        .tint(Color.accent)
        .navigationTitle(Text("Display name"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: save)
                    .disabled(!canSave)
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
        .onAppear {
            if name.isEmpty { name = session.profile?.displayName ?? "" }
            isFocused = true
        }
    }

    private var canSave: Bool {
        guard let valid = UserProfile.validDisplayName(name) else { return false }
        return valid != session.profile?.displayName
    }

    private func save() {
        guard canSave, let profile = session.profile else { return }
        do {
            try ProfileEditor().rename(profile, to: name)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}
