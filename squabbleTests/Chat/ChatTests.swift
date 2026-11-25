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
        ].map(ChatEntry.message), now: at(19, 12), calendar: calendar)

        let shape = rows.map { row -> String in
            switch row {
            case .day: "day"
            case .bill(let bill): bill.id
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
    private let bills = FakeBillRepository()

    init() {
        Container.shared.chatRepository.register { [repository] in repository }
        Container.shared.billRepository.register { [bills] in bills }
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

    private func messages(_ range: Range<Int>, text: String = "x") -> [ChatMessage] {
        range.map {
            ChatMessage(id: "m\($0)", authorID: "pal", createdAt: Date(timeIntervalSince1970: Double($0)), text: text)
        }
    }

    private func page(_ range: Range<Int>, text: String = "x", cached: Bool = false) -> FeedPage<ChatMessage> {
        FeedPage(items: messages(range, text: text), isFull: range.count >= ChatStore.pageSize, isFromCache: cached)
    }

    private func ids(_ range: Range<Int>) -> [String] { range.map { "m\($0)" } }

    @Test func aRefusalBeforeTheSquabbleReachesTheServerIsNotAFailure() async {
        repository.latestError = ChatError.unavailable
        let store = ChatStore(groupID: "g1")
        await store.observe(isAwaitingServer: true)
        #expect(store.hasLoaded)
        #expect(!store.failed)
        repository.latestError = nil
        repository.latest = [page(0..<3)]
        await store.observe()
        #expect(store.messages.map(\.id) == ids(0..<3))
    }

    @Test func aRefusalOtherwiseFailsUntilItWorksAgain() async {
        repository.latestError = ChatError.unavailable
        let store = ChatStore(groupID: "g1")
        await store.observe()
        #expect(store.failed)
        repository.latestError = nil
        await store.observe()
        #expect(!store.failed)
    }

    @Test func olderPagesGoBeforeTheLivePageWithoutDuplicates() async {
        repository.latest = [page(100..<150)]
        repository.olderPages = [page(90..<101, text: "stale")]
        let store = ChatStore(groupID: "g1")
        await store.observe()
        #expect(store.canLoadOlder)
        await store.loadOlder()
        #expect(store.messages.map(\.id) == ids(90..<150))
        #expect(store.message(id: "m100")?.text == "x")
        #expect(store.olderPageAnchor == "m100")
        #expect(!store.canLoadOlder)
    }

    @Test func aShortCachedPageDoesNotHideOlderMessages() async {
        repository.latest = [page(140..<150, cached: true), page(100..<150)]
        let store = ChatStore(groupID: "g1")
        await store.observe()
        #expect(store.messages.map(\.id) == ids(100..<150))
        #expect(store.canLoadOlder)
    }

    @Test func messagesTheLivePageMovesPastStay() async {
        repository.latest = [page(0..<49), page(0..<50), page(2..<52)]
        let store = ChatStore(groupID: "g1")
        await store.observe()
        #expect(store.messages.map(\.id) == ids(0..<52))
        #expect(!store.canLoadOlder)
    }

    @Test func loadedOlderPagesStayJoinedAsTheLivePageMoves() async {
        repository.latest = [page(100..<150)]
        repository.olderPages = [page(50..<100)]
        let store = ChatStore(groupID: "g1")
        await store.observe()
        await store.loadOlder()
        repository.latest = [page(103..<153, text: "new")]
        await store.observe()
        #expect(store.messages.map(\.id) == ids(50..<153))
        #expect(store.message(id: "m103")?.text == "new")
        #expect(store.canLoadOlder)
    }

    @Test func aGapStartsOverEvenWhenAnUnsentMessageOverlaps() async {
        let mine = ChatMessage(id: "mine", authorID: "pal", createdAt: Date(timeIntervalSince1970: 400), text: "x")
        repository.latest = [
            FeedPage(items: messages(1..<50) + [mine], isFull: true, isFromCache: true),
            FeedPage(items: messages(200..<249) + [mine], isFull: true, isFromCache: false),
        ]
        let store = ChatStore(groupID: "g1")
        await store.observe()
        #expect(store.messages.map(\.id) == ids(200..<249) + ["mine"])
        #expect(store.canLoadOlder)
    }

    @Test func aShortOlderPageFromTheCacheIsNotTheStart() async {
        repository.latest = [page(100..<150)]
        repository.olderPages = [page(95..<100, cached: true)]
        let store = ChatStore(groupID: "g1")
        await store.observe()
        await store.loadOlder()
        #expect(store.messages.first?.id == "m95")
        #expect(store.canLoadOlder)
    }
}
