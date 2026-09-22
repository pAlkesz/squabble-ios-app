import Foundation

/// The public face of a user: what other people see next to a bill or a reminder.
nonisolated struct UserProfile: Equatable, Sendable {
    let id: String
    var displayName: String
    var handle: Handle
    var avatar: Avatar

    static let maxDisplayNameLength = 40

    /// Trims the name and rejects anything empty or too long to fit on a receipt line.
    static func validDisplayName(_ input: String) -> String? {
        let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= maxDisplayNameLength else { return nil }
        return name
    }
}
