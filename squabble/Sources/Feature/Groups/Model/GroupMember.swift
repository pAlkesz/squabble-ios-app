import Foundation

/// A member's entry in a squabble: a copy of their public profile and payment details, so
/// group-mates can see where to send money without reading each other's private documents.
/// Former and deleted members keep their entry, so old bills still show who was involved.
nonisolated struct GroupMember: Identifiable, Equatable, Sendable {
    let id: String
    var displayName: String
    var handle: Handle?
    var avatar: Avatar
    var paymentMethods: [PaymentMethod]
    /// `nil` until the server has stamped it.
    var joinedAt: Date?
    var leftAt: Date?
    /// The account is gone; everything personal has been stripped.
    var isDeleted = false

    init(
        id: String,
        displayName: String,
        handle: Handle?,
        avatar: Avatar,
        paymentMethods: [PaymentMethod] = [],
        joinedAt: Date? = nil,
        leftAt: Date? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.avatar = avatar
        self.paymentMethods = paymentMethods
        self.joinedAt = joinedAt
        self.leftAt = leftAt
        self.isDeleted = isDeleted
    }

    /// Only the owner can read their payment details, so whoever adds someone else leaves
    /// them out; the member copies their own in later (see `GroupsStore`).
    init(profile: UserProfile, paymentMethods: [PaymentMethod] = []) {
        self.init(
            id: profile.id,
            displayName: profile.displayName,
            handle: profile.handle,
            avatar: profile.avatar,
            paymentMethods: paymentMethods
        )
    }

    /// Whether this entry already shows what the member's own profile says.
    func matches(_ profile: UserProfile, paymentMethods: [PaymentMethod]) -> Bool {
        displayName == profile.displayName
            && handle == profile.handle
            && avatar == profile.avatar
            && self.paymentMethods == paymentMethods
    }
}
