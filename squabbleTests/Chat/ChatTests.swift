import FactoryKit
import Foundation
import Testing
@testable import squabble

struct ChatMappingTests {
    @Test func roundTripsAReply() throws {
        let message = ChatMessage(
            id: "m2", authorID: "pal", text: "Who had the lobster?",
            replyTo: ChatReply(messageID: "m1", authorID: "anna", preview: "Dinner was great")
        )
        let read = try #require(ChatMessage(id: "m2", firestoreData: message.firestoreData))
        #expect(read == message)
        #expect(message.firestoreData["createdAt"] == nil)
    }

    @Test func aDeletedMessageReadsWithoutItsText() throws {
        let gone = Date(timeIntervalSince1970: 10)
        let read = try #require(ChatMessage(id: "m1", firestoreData: ["authorId": "pal", "kind": "text", "deletedAt": gone]))
        #expect(read.isDeleted)
        #expect(read.text.isEmpty)
    }

    @Test func unknownKindsAndMissingTextAreSkipped() {
        #expect(ChatMessage(id: "m1", firestoreData: ["authorId": "pal", "kind": "gif"]) == nil)
        #expect(ChatMessage(id: "m1", firestoreData: ["authorId": "pal", "kind": "text"]) == nil)
    }

    @Test func replyPreviewIsCapped() {
        let reply = ChatReply(messageID: "m1", authorID: "pal", preview: String(repeating: "a", count: 500))
        #expect(reply.preview.count == ChatReply.maxPreviewLength)
    }

    @Test func reactionsCountMostUsedFirstThenInQuickOrder() {
        let message = ChatMessage(id: "m1", authorID: "pal", text: "hi", reactions: ["a": "👍", "b": "❤️", "c": "👍", "d": "😂"])
        #expect(message.reactionCounts.map(\.emoji) == ["👍", "❤️", "😂"])
        #expect(message.reactionCounts.first?.count == 2)
    }
}

struct ChatTimelineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .gmt
        return calendar
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    private func message(_ id: String, _ author: String, _ date: Date) -> ChatMessage {
        ChatMessage(id: id, authorID: author, createdAt: date, text: id)
    }

    @Test func groupsRunsAndSplitsDays() {
        let rows = ChatTimeline.rows(for: [
            message("1", "anna", at(18, 19, 0)),
            message("2", "anna", at(18, 19, 2)),
            message("3", "pal", at(18, 19, 3)),
            message("4", "pal", at(18, 19, 30)),
            message("5", "pal", at(19, 9, 0)),
        ], now: at(19, 12), calendar: calendar)

        let shape = rows.map { row -> String in
            switch row {
            case .day: "day"
            case .message(let m, let starts, let ends): "\(m.id)\(starts ? "s" : "")\(ends ? "e" : "")"
            }
        }
        #expect(shape == ["day", "1s", "2e", "3se", "4se", "day", "5se"])
    }

    @Test func dayTitles() {
        let now = at(19, 12)
        #expect(ChatTimeline.dayTitle(for: at(19, 0), now: now, calendar: calendar) == String(localized: "Today"))
        #expect(ChatTimeline.dayTitle(for: at(18, 0), now: now, calendar: calendar) == String(localized: "Yesterday"))
        #expect(ChatTimeline.dayTitle(for: at(16, 0), now: now, calendar: calendar, locale: Locale(identifier: "en_US")) == "Monday")
        #expect(ChatTimeline.dayTitle(for: at(2, 0), now: now, calendar: calendar, locale: Locale(identifier: "en_US")) == "Nov 2")
    }
}

@MainActor
@Suite(.serialized)
struct ChatStoreTests {
    private let repository = FakeChatRepository()

    init() {
        Container.shared.chatRepository.register { [repository] in repository }
    }

    @Test func sendsTrimmedTextWithTheReplyAndIgnoresBlanks() {
        let store = ChatStore(groupID: "g1")
        let original = ChatMessage(id: "m1", authorID: "anna", text: "Pizza?")
        store.send("   ", replyingTo: nil, as: "pal")
        store.send("  Yes, obviously  ", replyingTo: original, as: "pal")
        #expect(repository.sent.count == 1)
        #expect(repository.sent.first?.text == "Yes, obviously")
        #expect(repository.sent.first?.replyTo == ChatReply(quoting: original))
        #expect(repository.sent.first?.authorID == "pal")
    }

    @Test func tappingYourOwnReactionTakesItBack() {
        let store = ChatStore(groupID: "g1")
        let message = ChatMessage(id: "m1", authorID: "anna", text: "hi", reactions: ["pal": "❤️"])
        store.toggleReaction("❤️", on: message, by: "pal")
        store.toggleReaction("😂", on: message, by: "pal")
        #expect(repository.reactions.map(\.emoji) == [nil, "😂"])
    }

    @Test func olderPagesGoBeforeTheLivePageWithoutDuplicates() async {
        let now = Date()
        repository.latest = (0..<ChatStore.pageSize).map {
            ChatMessage(id: "l\($0)", authorID: "pal", createdAt: now.addingTimeInterval(Double($0)), text: "x")
        }
        repository.olderPages = [[
            ChatMessage(id: "o1", authorID: "pal", createdAt: now.addingTimeInterval(-10), text: "x"),
            ChatMessage(id: "l0", authorID: "pal", createdAt: now, text: "stale"),
        ]]
        let store = ChatStore(groupID: "g1")
        await store.observe()
        #expect(store.canLoadOlder)
        await store.loadOlder()
        #expect(store.messages.first?.id == "o1")
        #expect(store.messages.filter { $0.id == "l0" }.map(\.text) == ["x"])
        #expect(store.messages.count == ChatStore.pageSize + 1)
        #expect(!store.canLoadOlder)
    }
}
