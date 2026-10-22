import SwiftUI

/// Pushed from the account screen. "Automatic" follows the phone's region and stays the
/// default until the user picks something else; choosing one saves it and pops back.
struct HomeCurrencyPicker: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var failure: String?

    private let options = CurrencyOption.all()

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    row(
                        code: nil,
                        title: Text("Automatic", comment: "Home currency picker: follow the phone's region."),
                        detail: UserPreferences.deviceCurrencyCode
                    )
                } footer: {
                    Text(
                        "Follows your phone's region. Totals are converted into this currency, so pick the one your bank account thinks in.",
                        comment: "Home currency picker: footer under the Automatic row."
                    )
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
            Section {
                ForEach(options.filter { $0.matches(query) }) { option in
                    row(code: option.code, title: Text(verbatim: option.name), detail: option.code)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(Text("Home currency"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: failure ?? "")
        }
    }

    /// `nil` is the automatic row.
    private func row(code: String?, title: Text, detail: String) -> some View {
        let isSelected = preferences.preferences.homeCurrencyCode == code
        return Button {
            choose(code)
        } label: {
            HStack {
                title
                Spacer()
                Text(verbatim: detail)
                    .font(.body.monospaced())
                    .foregroundStyle(.white.opacity(0.6))
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accent)
                    .opacity(isSelected ? 1 : 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.white.opacity(0.08))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func choose(_ code: String?) {
        do {
            try preferences.setHomeCurrency(code)
            dismiss()
        } catch {
            failure = error.localizedDescription
        }
    }
}
