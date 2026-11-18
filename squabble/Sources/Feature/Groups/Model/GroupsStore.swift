import FactoryKit
import Foundation
import Observation

/// The signed-in user's squabbles, kept live for as long as home is up and shared with the
/// pages pushed from it. Also keeps the user's own entry in each squabble in step with
/// their profile and payment details, which is how profile edits reach group-mates.
@Observable
final class GroupsStore {
    private(set) var groups: [SquabbleGroup] = []
    /// False until the first answer, so home doesn't flash its empty state.
    private(set) var hasLoaded = false
    /// `nil` until the first answer: syncing before then would wipe the copies.
    private(set) var paymentMethods: [PaymentMethod]?
    private var uid: String?

    /// Set by home from the session; any change is copied into the user's groups.
    var profile: UserProfile? {
        didSet {
            guard profile != oldValue else { return }
            syncOwnEntries()
        }
    }

    private let repository: GroupRepository
    private let profiles: ProfileRepository

    init(
        repository: GroupRepository = Container.shared.groupRepository(),
        profiles: ProfileRepository = Container.shared.profileRepository()
    ) {
        self.repository = repository
        self.profiles = profiles
    }

    func group(id: String) -> SquabbleGroup? {
        groups.first { $0.id == id }
    }

    func observe(uid: String) async {
        self.uid = uid
        async let groups: Void = observeGroups(of: uid)
        async let payment: Void = observePaymentMethods(of: uid)
        _ = await (groups, payment)
    }

    /// Saves the new squabble to the local cache and returns its id; it shows up in
    /// `groups` through the listener, offline too.
    func create(_ draft: NewSquabbleDraft) throws -> String {
        guard uid == draft.creator.id else { throw GroupError.notSignedIn }
        guard let group = draft.makeGroup(id: UUID().uuidString, creatorPaymentMethods: paymentMethods ?? []) else {
            throw GroupError.invalidName
        }
        try repository.createGroup(group)
        return group.id
    }

    /// Newest activity first; a group without a timestamp yet was only just created.
    nonisolated static func sorted(_ groups: [SquabbleGroup]) -> [SquabbleGroup] {
        groups.sorted { lhs, rhs in
            let left = lhs.updatedAt ?? .distantFuture
            let right = rhs.updatedAt ?? .distantFuture
            if left != right { return left > right }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func observeGroups(of uid: String) async {
        do {
            for try await groups in repository.groupChanges(for: uid) {
                self.groups = Self.sorted(groups)
                hasLoaded = true
                syncOwnEntries()
            }
        } catch {
            // Signing out kills the listener with a permission error; that's not a failure.
            guard !Task.isCancelled else { return }
            AppLog.error(error, "Groups listener failed")
        }
    }

    private func observePaymentMethods(of uid: String) async {
        do {
            for try await methods in profiles.paymentMethodChanges(for: uid) {
                paymentMethods = methods
                syncOwnEntries()
            }
        } catch {
            guard !Task.isCancelled else { return }
            AppLog.error(error, "Payment methods listener failed")
        }
    }

    /// Writes land in the cache at once and come back through the listener already
    /// matching, so this settles after one round.
    private func syncOwnEntries() {
        guard hasLoaded, let profile, profile.id == uid, let paymentMethods else { return }
        for update in OwnEntrySync.updates(for: groups, profile: profile, paymentMethods: paymentMethods) {
            do {
                try repository.updateOwnEntry(update.entry, in: update.groupID)
            } catch {
                AppLog.error(error, "Group member entry update failed")
            }
        }
    }
}
