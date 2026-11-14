import SwiftUI

/// Pushed from the account screen. "Automatic" follows the phone's region and stays the
/// default until the user picks something else; choosing one saves it and pops back.
struct HomeCurrencyPicker: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var failure: String?

    /// Built once: ~150 localized names are too much to redo on every view update, and
    /// the first build would otherwise land in the middle of the push.
    private static let options = CurrencyOption.all()

    var body: some View {
        List {
            // Always shown, even while searching: inserting it as the search is cancelled
            // shoved the list down just as the search bar slid back up.
            Section {
                row(
                    code: nil,
                    flag: deviceCurrency,
                    title: Text("Automatic", comment: "Home currency picker: follow the phone's region."),
                    detail: "\(deviceCurrency.code) · \(deviceCurrency.name)"
                )
            } footer: {
                Text(
                    "Follows your phone's region. Totals are converted into this currency, so pick the one your bank account thinks in.",
                    comment: "Home currency picker: footer under the Automatic row."
                )
                .foregroundStyle(.white.opacity(0.7))
            }
            Section {
                ForEach(Self.options.filter { $0.matches(query) }) { option in
                    row(code: option.code, flag: option, title: Text(verbatim: option.name), detail: detail(for: option))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(Text("Default currency"))
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
    private var deviceCurrency: CurrencyOption {
        CurrencyOption(code: UserPreferences.deviceCurrencyCode)
    }

    /// "HUF · Hungary", or just the code when no single country goes with it.
    private func detail(for option: CurrencyOption) -> String {
        option.countryName.map { "\(option.code) · \($0)" } ?? option.code
    }

    private func row(code: String?, flag: CurrencyOption, title: Text, detail: String) -> some View {
        let isSelected = preferences.preferences.homeCurrencyCode == code
        return Button {
            choose(code)
        } label: {
            HStack(spacing: 14) {
                CurrencyFlag(option: flag)
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(.body.weight(.semibold))
                    Text(verbatim: detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
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
