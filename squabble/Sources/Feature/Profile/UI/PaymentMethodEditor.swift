import SwiftUI

/// Sheet for adding one bank account or payment link. Validation messages only appear
/// after the first attempt to add, so nobody gets scolded for a half-typed IBAN.
struct PaymentMethodEditor: View {
    private enum Kind: CaseIterable {
        case bankAccount
        case link
    }

    let defaultHolderName: String
    let onAdd: (PaymentMethod) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .bankAccount
    @State private var holderName = ""
    @State private var iban = ""
    @State private var provider: PaymentProvider = .revolut
    @State private var username = ""
    @State private var hasTriedAdding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Type", selection: $kind) {
                        Text("Bank account").tag(Kind.bankAccount)
                        Text("Payment link").tag(Kind.link)
                    }
                    .pickerStyle(.segmented)

                    switch kind {
                    case .bankAccount: bankAccountFields
                    case .link: linkFields
                    }
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.backdropDeep)
            .navigationTitle("Add a way to pay you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(!hasInput)
                }
            }
        }
        .presentationBackground(Color.backdropDeep)
        .onAppear {
            if holderName.isEmpty { holderName = defaultHolderName }
        }
    }

    private var bankAccountFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            SquabbleField(title: "Account holder", message: holderNameMessage) {
                TextField("Name on the account", text: $holderName)
                    .textContentType(.name)
            }
            SquabbleField(title: "IBAN", message: ibanMessage) {
                TextField(text: $iban, prompt: Text(verbatim: "HU42 1177 3016 1111 1018 0000 0000")) {
                    Text("IBAN")
                }
                .font(.body.monospaced())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
            }
        }
    }

    private var linkFields: some View {
        VStack(alignment: .leading, spacing: 20) {
            SquabbleField(title: "Service") {
                Picker("Service", selection: $provider) {
                    ForEach(PaymentProvider.allCases, id: \.self) { provider in
                        Text(verbatim: provider.name).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            SquabbleField(title: "Username or link", message: linkMessage) {
                HStack(spacing: 2) {
                    Text(verbatim: provider.linkPrefixes[0])
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
            }
        }
    }

    private var hasInput: Bool {
        switch kind {
        case .bankAccount: !iban.isEmpty && !holderName.isEmpty
        case .link: !username.isEmpty
        }
    }

    private var trimmedHolderName: String? {
        let name = holderName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private var holderNameMessage: SquabbleFieldMessage? {
        guard hasTriedAdding, trimmedHolderName == nil else { return nil }
        return .init(text: String(localized: "Whose account is it?"), tone: .problem)
    }

    private var ibanMessage: SquabbleFieldMessage? {
        guard hasTriedAdding else {
            return .init(text: String(localized: "Only people you split bills with will see this."), tone: .hint)
        }
        do throws(IBANError) {
            _ = try IBAN(validating: iban)
            return nil
        } catch {
            return .init(text: error.localizedDescription, tone: .problem)
        }
    }

    private var linkMessage: SquabbleFieldMessage? {
        guard hasTriedAdding else { return nil }
        do throws(PaymentLinkError) {
            _ = try PaymentLink(provider: provider, input: username)
            return nil
        } catch {
            return .init(text: error.localizedDescription, tone: .problem)
        }
    }

    private func add() {
        hasTriedAdding = true
        let method: PaymentMethod
        switch kind {
        case .bankAccount:
            guard let holderName = trimmedHolderName, let iban = try? IBAN(validating: iban) else { return }
            method = PaymentMethod(kind: .bankAccount(iban: iban, holderName: holderName))
        case .link:
            guard let link = try? PaymentLink(provider: provider, input: username) else { return }
            method = PaymentMethod(kind: .link(link))
        }
        onAdd(method)
        dismiss()
    }
}
