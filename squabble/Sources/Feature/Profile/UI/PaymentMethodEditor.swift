import SwiftUI

/// Sheet for adding one bank account or payment link. Which one is decided before it
/// opens (by the tile that was tapped), so the sheet only asks for that kind's fields.
/// Validation messages only appear after the first attempt to add, so nobody gets
/// scolded for a half-typed number.
struct PaymentMethodEditor: View {
    enum Kind: Hashable, Identifiable {
        case bankAccount
        case link(PaymentProvider)

        var id: Self { self }
    }

    let kind: Kind
    let defaultHolderName: String
    let onAdd: (PaymentMethod) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var holderName = ""
    @State private var accountNumber = ""
    @State private var username = ""
    @State private var hasTriedAdding = false
    @FocusState private var isEntryFocused: Bool

    var body: some View {
        // A plain stack, not a Form, as in ThermalGlass's bug report sheet: inside a Form
        // `focusOnAppear`'s hidden first responder only hands over on the first sheet.
        NavigationStack {
            VStack(spacing: 24) {
                switch kind {
                case .bankAccount: bankAccountFields
                case .link(let provider): linkField(for: provider)
                }
            }
            .padding(20)
            .frame(maxHeight: .infinity, alignment: .top)
            // The asset colour, not `Color.accentColor`: on a device the fields' cursor
            // picked up the system-adjusted tint and came out grey instead of green.
            .tint(Color.accent)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: add)
                        .tint(.accentColor)
                        .disabled(!hasInput)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.backdropDeep)
        .onAppear {
            if holderName.isEmpty { holderName = defaultHolderName }
        }
    }

    private var title: Text {
        switch kind {
        case .bankAccount:
            Text("Bank account", comment: "Payment method editor sheet: title when adding a bank account.")
        case .link(let provider):
            Text("\(provider.name) link", comment: "Payment method editor sheet: title when adding a payment link, with the service's name.")
        }
    }

    @ViewBuilder
    private var bankAccountFields: some View {
        field(Text("Account holder"), message: holderNameMessage) {
            TextField("Name on the account", text: $holderName)
                .textContentType(.name)
        }
        field(Text("Account number or IBAN", comment: "Payment method editor: bank account field."), message: accountNumberMessage) {
            TextField(text: $accountNumber, prompt: Text(verbatim: "11773016-11111018")) {
                Text("Account number or IBAN", comment: "Payment method editor: bank account field.")
            }
            .font(.body.monospaced())
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            // Formats as it's typed, so the number reads in blocks like on a bank statement.
            // In onChange rather than a formatting binding: a field ignores a value its own
            // binding rewrites mid-keystroke, but picks up this separate update.
            .onChange(of: accountNumber) { _, typed in
                let formatted = BankAccountNumberFormatter.format(typed)
                if formatted != typed { accountNumber = formatted }
            }
            // The holder is prefilled from the profile, so the number is what's left to type.
            .focusOnAppear($isEntryFocused, config: .init(keyboardType: .asciiCapable))
        }
    }

    private func linkField(for provider: PaymentProvider) -> some View {
        field(
            Text("\(provider.name) username or link", comment: "Payment method editor: link field header, with the service's name."),
            message: linkMessage
        ) {
            HStack(spacing: 2) {
                Text(verbatim: provider.linkPrefixes[0])
                    .foregroundStyle(.secondary)
                TextField("username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focusOnAppear($isEntryFocused, config: .init(keyboardType: .URL))
            }
        }
    }

    /// A header, the input in a rounded box, and its message underneath — the parts a
    /// Form section used to provide.
    private func field(
        _ header: Text,
        message: SquabbleFieldMessage?,
        @ViewBuilder input: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header
                .font(.headline)
                .padding(.horizontal, 4)
            input()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            FieldMessageFooter(message: message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var hasInput: Bool {
        switch kind {
        case .bankAccount: !accountNumber.isEmpty && !holderName.isEmpty
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

    /// Once the number checks out, shows it in the other format, so a typed domestic
    /// number visibly became an IBAN (and the other way round).
    private var accountNumberMessage: SquabbleFieldMessage? {
        do {
            let iban = try IBAN(validatingAccountNumber: accountNumber)
            return .init(text: Self.confirmation(for: iban, typed: accountNumber), tone: .hint)
        } catch {
            guard hasTriedAdding else {
                return .init(text: String(localized: "Only people you split bills with will see this."), tone: .hint)
            }
            return .init(text: error.localizedDescription, tone: .problem)
        }
    }

    private static func confirmation(for iban: IBAN, typed: String) -> String {
        let typedIBAN = typed.first(where: { !$0.isWhitespace })?.isLetter ?? false
        if typedIBAN, let domestic = HungarianAccountNumber(iban: iban) {
            return String(localized: "Account number: \(domestic.formatted)", comment: "Payment method editor: the typed IBAN as a Hungarian account number.")
        }
        return String(localized: "IBAN: \(iban.formatted)", comment: "Payment method editor: the typed account number as an IBAN.")
    }

    private var linkMessage: SquabbleFieldMessage? {
        guard hasTriedAdding, case .link(let provider) = kind else { return nil }
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
            guard let holderName = trimmedHolderName,
                  let iban = try? IBAN(validatingAccountNumber: accountNumber)
            else { return }
            method = PaymentMethod(kind: .bankAccount(iban: iban, holderName: holderName))
        case .link(let provider):
            guard let link = try? PaymentLink(provider: provider, input: username) else { return }
            method = PaymentMethod(kind: .link(link))
        }
        onAdd(method)
        dismiss()
    }
}
