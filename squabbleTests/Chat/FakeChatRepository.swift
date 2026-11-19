import Foundation
@testable import squabble

final class FakeChatRepository: ChatRepository, @unchecked Sendable {
    var latest: [ChatMessage] = []
    var olderPages: [[ChatMessage]] = []
    private(set) var sent: [ChatMessage] = []
    private(set) var reactions: [(emoji: String?, uid: String, messageID: String)] = []
    private(set) var deleted: [String] = []
    private var nextID = 0

    func latestMessages(in groupID: String, limit: Int) -> AsyncThrowingStream<[ChatMessage], Error> {
        let page = latest
        return AsyncThrowingStream { continuation in
            continuation.yield(page)
            continuation.finish()
        }
    }

    func messages(in groupID: String, before date: Date, limit: Int) async throws -> [ChatMessage] {
        olderPages.isEmpty ? [] : olderPages.removeFirst()
    }

    func send(_ message: ChatMessage, in groupID: String) throws { sent.append(message) }

    func setReaction(_ emoji: String?, by uid: String, on messageID: String, in groupID: String) throws {
        reactions.append((emoji, uid, messageID))
    }

    func delete(_ messageID: String, in groupID: String) throws { deleted.append(messageID) }
    func report(_ message: ChatMessage, in groupID: String, by uid: String) throws {}

    func newMessageID(in groupID: String) -> String {
        nextID += 1
        return "new\(nextID)"
    }
}
