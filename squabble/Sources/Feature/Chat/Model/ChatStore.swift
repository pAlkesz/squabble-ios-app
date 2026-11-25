import FactoryKit
import Foundation
import Observation

/// One squabble's chat, owned by its page: the latest page live, older pages loaded on
/// demand as the user scrolls up.
@Observable
final class ChatStore {
    static let pageSize = 50

    private(set) var messages: [ChatMessage] = []
    private(set) var hasLoaded = false
    private(set) var failed = false
    private(set) var isLoadingOlder = false
    /// The message the last older page was added above.
    private(set) var olderPageAnchor: String?

    @ObservationIgnored @Injected(\.chatRepository) private var repository
    /// The server has answered since the last time the connection dropped.
    private(set) var isLive = false
    private var isLatestFull = false
    private var hasReachedStart = false
    let groupID: String

    init(groupID: String) {
        self.groupID = groupID
    }

    var canLoadOlder: Bool { isLatestFull && !hasReachedStart }

    func observe() async {
        do {
            for try await page in repository.latestMessages(in: groupID, limit: Self.pageSize) {
                show(latest: page)
                hasLoaded = true
            }
        } catch {
            AppLog.error(error, "Chat listener failed")
            failed = true
            hasLoaded = true
        }
    }

    func loadOlder() async {
        guard canLoadOlder, !isLoadingOlder, let oldest = messages.first, let date = oldest.createdAt else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await repository.messages(in: groupID, before: date, limit: Self.pageSize)
            // The live page started over meanwhile, so this one no longer joins on.
            guard messages.first?.id == oldest.id else { return }
            let known = Set(messages.map(\.id))
            messages = page.messages.filter { !known.contains($0.id) } + messages
            if messages.first?.id != oldest.id { olderPageAnchor = oldest.id }
            // The cache only holds what this phone has seen, so it can't say where it starts.
            if !page.isFromCache, !page.isFull { hasReachedStart = true }
        } catch {
            AppLog.error(error, "Loading older messages failed")
        }
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

    /// Puts the live page after what's already loaded: it wins where they overlap (it has the
    /// latest reactions and deletions), and what it has moved past stays above it.
    private func show(latest page: ChatPage) {
        isLive = !page.isFromCache
        isLatestFull = page.isFull
        if !page.isFromCache, !page.isFull {
            // The server's whole chat fits in one page.
            messages = page.messages
            hasReachedStart = true
        } else if let first = page.messages.first, let index = messages.firstIndex(where: { $0.id == first.id }) {
            messages = messages[..<index] + page.messages
        } else {
            // No overlap at its start: there may be messages in between (a long time offline),
            // so start over rather than leave a silent hole.
            messages = page.messages
            hasReachedStart = false
        }
    }
}
