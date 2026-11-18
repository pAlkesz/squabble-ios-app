import SwiftUI

/// Pushed from the new-squabble screen: every common currency, searchable. Choosing one
/// pops back.
struct SquabbleCurrencyPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    /// Built once: ~150 localized names are too much to redo on every view update.
    private static let options = CurrencyOption.all()

    var body: some View {
        List {
            ForEach(Self.options.filter { $0.matches(query) }) { option in
                CurrencyRow(
                    flag: option,
                    title: Text(verbatim: option.name),
                    detail: CurrencyRow.detail(for: option),
                    isSelected: option.code == selection
                ) {
                    selection = option.code
                    dismiss()
                }
            }
        }
        .scrollContentBackground(.hidden)
        // Same as the home currency picker: cancelling the search animates the list's
        // update inside UIKit's cancel animation unless its updates never animate.
        .transaction { transaction in
            transaction.disablesAnimations = true
            transaction.animation = nil
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(Text("Currency"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
