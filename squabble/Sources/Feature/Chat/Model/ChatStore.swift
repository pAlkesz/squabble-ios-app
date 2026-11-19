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
    private(set) var canLoadOlder = true
    private(set) var isLoadingOlder = false

    @ObservationIgnored @Injected(\.chatRepository) private var repository
    @ObservationIgnored private var latest: [ChatMessage] = []
    @ObservationIgnored private var older: [ChatMessage] = []
    let groupID: String

    init(groupID: String) {
        self.groupID = groupID
    }

    func observe() async {
        do {
            for try await page in repository.latestMessages(in: groupID, limit: Self.pageSize) {
                latest = page
                // A short first page means there's nothing older.
                if !hasLoaded { canLoadOlder = page.count == Self.pageSize }
                merge()
                hasLoaded = true
            }
        } catch {
            AppLog.error(error, "Chat listener failed")
            failed = true
            hasLoaded = true
        }
    }

    func loadOlder() async {
        guard canLoadOlder, !isLoadingOlder, let oldest = messages.first?.createdAt else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await repository.messages(in: groupID, before: oldest, limit: Self.pageSize)
            canLoadOlder = page.count == Self.pageSize
            older = page + older
            merge()
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

    /// The live page wins where pages overlap: it has the latest reactions and deletions.
    private func merge() {
        let liveIDs = Set(latest.map(\.id))
        messages = older.filter { !liveIDs.contains($0.id) } + latest
    }
}
