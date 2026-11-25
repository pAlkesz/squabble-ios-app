/// A line on an itemized bill, split equally among the people who had it.
nonisolated struct BillItem: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var amountMinor: Int64
    var sharedBy: Set<String>
}
