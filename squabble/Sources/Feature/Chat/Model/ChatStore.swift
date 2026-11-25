import FactoryKit
import Foundation
import Observation

/// One squabble's timeline, owned by its page: its messages and bills, the latest of each live
/// and older ones loaded on demand as the user scrolls up.
@Observable
final class ChatStore {
    static let pageSize = 50

    private var messageFeed = PagedFeed<ChatMessage>()
    private var billFeed = PagedFeed<Bill>()
    private(set) var entries: [ChatEntry] = []
    private(set) var failed = false
    private(set) var isLoadingOlder = false
    /// The entry the last older page was added above.
    private(set) var olderPageAnchor: String?

    @ObservationIgnored @Injected(\.chatRepository) private var repository
    @ObservationIgnored @Injected(\.billRepository) private var billRepository
    let groupID: String

    init(groupID: String) {
        self.groupID = groupID
    }

    var hasLoaded: Bool { messageFeed.hasLoaded && billFeed.hasLoaded }
    var isLive: Bool { messageFeed.isLive && billFeed.isLive }
    var canLoadOlder: Bool { messageFeed.canLoadOlder || billFeed.canLoadOlder }
    var messages: [ChatMessage] { messageFeed.items }

    func observe() async {
        async let messages: Void = observeMessages()
        async let bills: Void = observeBills()
        _ = await (messages, bills)
    }

    /// Loads whichever is holding the timeline back: the one known the least far back.
    func loadOlder() async {
        let since = [messageFeed.loadedSince, billFeed.loadedSince].compactMap(\.self).max()
        guard let since, !isLoadingOlder else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            if messageFeed.loadedSince == since, let oldest = messageFeed.items.first {
                let page = try await repository.messages(in: groupID, before: since, limit: Self.pageSize)
                messageFeed.add(older: page, before: oldest)
            }
            if billFeed.loadedSince == since, let oldest = billFeed.items.first {
                let page = try await billRepository.bills(in: groupID, before: since, limit: Self.pageSize)
                billFeed.add(older: page, before: oldest)
            }
        } catch {
            AppLog.error(error, "Loading older chat failed")
        }
        let first = entries.first?.id
        merge()
        if let first, entries.first?.id != first, entries.contains(where: { $0.id == first }) {
            olderPageAnchor = first
        }
    }

    func bill(id: String) -> Bill? {
        billFeed.items.first { $0.id == id }
    }

    func save(_ bill: Bill, isNew: Bool) {
        perform {
            if isNew {
                try billRepository.add(bill, in: groupID)
            } else {
                try billRepository.update(bill, in: groupID)
            }
        }
    }

    func delete(_ bill: Bill, by uid: String) {
        perform { try billRepository.delete(bill.id, by: uid, in: groupID) }
    }

    func message(id: String) -> ChatMessage? {
        messages.first { $0.id == id }
    }

    func send(_ text: String, replyingTo reply: ChatMessage?, as uid: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = ChatMessage(
            id: repository.newMessageID(in: groupID),
            authorID: uid,
            text: String(trimmed.prefix(ChatMessage.maxLength)),
            replyTo: reply.map(ChatReply.init(quoting:))
        )
        perform { try repository.send(message, in: groupID) }
    }

    /// Tapping the reaction you already have takes it back.
    func toggleReaction(_ emoji: String, on message: ChatMessage, by uid: String) {
        let next = message.reactions[uid] == emoji ? nil : emoji
        perform { try repository.setReaction(next, by: uid, on: message.id, in: groupID) }
    }

    func delete(_ message: ChatMessage) {
        perform { try repository.delete(message.id, in: groupID) }
    }

    func report(_ message: ChatMessage, by uid: String) {
        perform { try repository.report(message, in: groupID, by: uid) }
    }

    private func perform(_ write: () throws -> Void) {
        do {
            try write()
        } catch {
            AppLog.error(error, "Chat write failed")
        }
    }

    private func observeMessages() async {
        do {
            for try await page in repository.latestMessages(in: groupID, limit: Self.pageSize) {
                messageFeed.show(latest: page)
                merge()
            }
        } catch {
            AppLog.error(error, "Chat listener failed")
            failed = true
            messageFeed.fail()
        }
    }

    private func observeBills() async {
        do {
            for try await page in billRepository.latestBills(in: groupID, limit: Self.pageSize) {
                billFeed.show(latest: page)
                merge()
            }
        } catch {
            AppLog.error(error, "Bills listener failed")
            failed = true
            billFeed.fail()
        }
    }

    private func merge() {
        entries = ChatEntry.merged(messageFeed, billFeed)
    }
}
