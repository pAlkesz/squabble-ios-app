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
            if showsAutomatic {
                Section {
                    row(
                        code: nil,
                        flag: deviceCurrency,
                        title: Text(verbatim: Self.automaticTitle),
                        detail: "\(deviceCurrency.code) · \(deviceCurrency.name)"
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
                ForEach(Self.options.filter { $0.matches(query) }) { option in
                    row(code: option.code, flag: option, title: Text(verbatim: option.name), detail: detail(for: option))
                }
            }
        }
        .scrollContentBackground(.hidden)
        // Cancelling the search updates the list inside UIKit's cancel animation, typed text or
        // not, and that update got animated too: the list dropped ~200 pt, then snapped back.
        // Nothing in the list animates on purpose, so its updates never do.
        .transaction { transaction in
            transaction.disablesAnimations = true
            transaction.animation = nil
        }
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

    private static let automaticTitle = String(localized: "Automatic", comment: "Home currency picker: follow the phone's region.")

    /// While searching, only when it's a result in its own right: by its name, or by the
    /// device currency it stands for.
    private var showsAutomatic: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty
            || Self.automaticTitle.localizedStandardContains(trimmed)
            || deviceCurrency.matches(trimmed)
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
