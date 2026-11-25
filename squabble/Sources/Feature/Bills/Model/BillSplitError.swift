nonisolated enum BillSplitError: Error, Equatable {
    case noParticipants
    case duplicateParticipant
    /// A share or item names someone who isn't on the bill.
    case unknownParticipant
    case itemWithoutPeople(itemID: String)
    case negativeWeight
    /// Every weight is zero, so there's nothing to go by.
    case noWeight
    /// The total minus the entered shares: positive means some is still unassigned.
    case doesNotAddUp(missingMinor: Int64)
    case amountTooLarge
}
