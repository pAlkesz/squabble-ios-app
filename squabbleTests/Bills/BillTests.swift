import Foundation
import Testing
@testable import squabble

struct BillTests {
    private let group = SquabbleGroup(
        id: "g", name: "Flat", currencyCode: "EUR", createdBy: "anna",
        memberIds: ["anna", "bela", "cili"],
        members: Dictionary(uniqueKeysWithValues: ["anna", "bela", "cili"].map { ($0, GroupMember(profile: GroupTestData.profile($0))) })
    )

    private func draft(_ amount: String, title: String = "Dinner", id: String = "bill") -> BillDraft {
        var draft = BillDraft(newBillIn: group, by: "anna", id: id)
        draft.setAmount(amount)
        draft.setTitle(title)
        return draft
    }

    @Test func aNewBillIsSplitEquallyAndPaidByWhoeverAddsIt() throws {
        let bill = try #require(draft("84").makeBill(by: "anna"))
        #expect(bill.totalMinor == 8400)
        #expect(bill.shares == ["anna": 2800, "bela": 2800, "cili": 2800])
        #expect(bill.effect(on: "anna").minorUnits == 5600)
        #expect(bill.effect(on: "bela").minorUnits == -2800)
        #expect(["anna", "bela", "cili"].map { bill.effect(on: $0).minorUnits }.reduce(0, +) == 0)
    }

    @Test func nothingToSaveWithoutAnAmountATitleOrPeople() {
        #expect(!draft("").canSave)
        #expect(!draft("0").canSave)
        #expect(!draft("10", title: "  ").canSave)
        #expect(!draft("99999999999999").canSave)
        var nobody = draft("10")
        nobody.candidates.forEach { nobody.toggle($0) }
        #expect(!nobody.canSave)
    }

    @Test func leavingSomeoneOut() throws {
        var draft = draft("10")
        draft.toggle("cili")
        #expect(draft.shares == ["anna": 500, "bela": 500])
        #expect(!draft.includesEveryone)
    }

    @Test func exactAmountsStartFromTheEqualSplitAndMustAddUp() throws {
        var draft = draft("10")
        draft.setSplit(.exactly)
        #expect(draft.canSave)
        draft.setExact("0", for: "anna")
        #expect(!draft.canSave)
        let missing = try #require(draft.missing)
        #expect(missing.minorUnits == 333 || missing.minorUnits == 334)
        draft.setExact("5", for: "bela")
        draft.setExact("5", for: "cili")
        #expect(draft.makeBill(by: "anna")?.shares == ["bela": 500, "cili": 500])
        draft.setExact("6", for: "cili")
        #expect(draft.missing?.minorUnits == -100)
    }

    @Test func editingKeepsWhoAddedItAndComesBackTheSame() throws {
        var original = try #require(draft("10").makeBill(by: "bela"))
        original.createdAt = Date(timeIntervalSince1970: 5)
        let edit = BillDraft(editing: original, in: group)
        let saved = try #require(edit.makeBill(by: "anna"))
        #expect(saved.createdBy == "bela")
        #expect(saved.updatedBy == "anna")
        #expect(saved.shares == original.shares)
        #expect(saved.totalMinor == original.totalMinor)
    }

    @Test func editingKeepsPeopleWhoHaveLeft() throws {
        let original = try #require(draft("9").makeBill(by: "anna"))
        var smaller = group
        smaller.memberIds = ["anna", "bela"]
        let edit = BillDraft(editing: original, in: smaller)
        #expect(edit.candidates == ["anna", "bela", "cili"])
        #expect(edit.makeBill(by: "anna")?.shares == original.shares)
        #expect(BillDraft(newBillIn: smaller, by: "anna").candidates == ["anna", "bela"])
    }

    @Test func leftoversMoveAroundButNotBetweenPhones() throws {
        let luckless = Set((0..<40).compactMap { index in
            draft("10", id: "bill\(index)").shares?.first { $0.value == 334 }?.key
        })
        #expect(luckless == ["anna", "bela", "cili"])
        #expect(BillSplit.rotated(["cili", "anna", "bela"], by: "x") == BillSplit.rotated(["anna", "bela", "cili"], by: "x"))
    }

    @Test func roundTripsThroughFirestore() throws {
        let bill = try #require(draft("10").makeBill(by: "anna"))
        let read = try #require(Bill(id: "bill", firestoreData: bill.firestoreData))
        #expect(read == bill)
        #expect(Bill(id: "bill", firestoreData: ["title": "x"]) == nil)
    }

    @Test func sides() throws {
        let bill = try #require(draft("9").makeBill(by: "anna"))
        let euros = { Money(minorUnits: $0, currencyCode: "EUR") }
        #expect(BillSide(bill: bill, uid: "anna") == .owedToYou(euros(600)))
        #expect(BillSide(bill: bill, uid: "bela") == .youOwe(to: "anna", euros(300)))
        #expect(BillSide(bill: bill, uid: "dora") == .notInvolved(euros(900)))
    }
}

struct AmountInputTests {
    private let english = Locale(identifier: "en_US")
    private let hungarian = Locale(identifier: "hu_HU")

    @Test(arguments: [
        ("12.345", "12.34"), ("12,5", "12.5"), ("abc7", "7"), ("007", "7"), ("0", "0"), (".5", "0.5"), ("", ""), ("1.", "1."),
    ])
    func sanitizesEuros(input: String, expected: String) {
        #expect(AmountInput.sanitized(input, currencyCode: "EUR", locale: english) == expected)
    }

    @Test func forintsHaveNoDecimals() {
        #expect(AmountInput.sanitized("1 500", currencyCode: "HUF", locale: hungarian) == "1500")
        #expect(AmountInput.money(from: "1500", currencyCode: "HUF", locale: hungarian)?.minorUnits == 1500)
    }

    @Test func readsTheLocalesSeparator() {
        #expect(AmountInput.sanitized("12.5", currencyCode: "EUR", locale: hungarian) == "12,5")
        #expect(AmountInput.money(from: "12,5", currencyCode: "EUR", locale: hungarian)?.minorUnits == 1250)
        #expect(AmountInput.money(from: "1.", currencyCode: "EUR", locale: english)?.minorUnits == 100)
        #expect(AmountInput.money(from: "", currencyCode: "EUR", locale: english) == nil)
    }

    @Test func textComesBackAsTheSameMoney() {
        let money = Money(minorUnits: 123_456, currencyCode: "EUR")
        #expect(AmountInput.text(for: money, locale: hungarian) == "1234,56")
        #expect(AmountInput.money(from: "1234,56", currencyCode: "EUR", locale: hungarian) == money)
    }
}

struct CalendarDayTests {
    @Test func roundTrips() throws {
        let day = try #require(CalendarDay(rawValue: "2026-03-29"))
        #expect(day.rawValue == "2026-03-29")
        #expect(CalendarDay(day.date()) == day)
        #expect(CalendarDay(rawValue: "2026-3-29") == nil)
        #expect(CalendarDay(rawValue: "2026-13-01") == nil)
    }

    @Test func storedDaysAreGregorianWhateverThePhoneUses() throws {
        let buddhist = Calendar(identifier: .buddhist)
        let day = try #require(CalendarDay(rawValue: "2026-11-25"))
        #expect(CalendarDay(day.date(calendar: buddhist), calendar: buddhist) == day)
    }
}

struct HomeTotalTests {
    private func group(_ id: String, _ currency: String, _ balance: Int64) -> SquabbleGroup {
        var group = SquabbleGroup(id: id, name: id, currencyCode: currency, createdBy: "pal", memberIds: ["pal"], members: [:])
        group.balances = ["pal": balance]
        return group
    }

    @Test func addsUpPerCurrency() {
        let total = HomeTotal(
            groups: [group("a", "HUF", 500), group("b", "HUF", -200), group("c", "USD", -700), group("d", "EUR", 100), group("e", "EUR", -100)],
            uid: "pal", homeCurrencyCode: "HUF"
        )
        #expect(total.home == Money(minorUnits: 300, currencyCode: "HUF"))
        #expect(total.others == [Money(minorUnits: -700, currencyCode: "USD")])
    }
}

struct ChatEntryTests {
    private func message(_ seconds: Double) -> ChatMessage {
        ChatMessage(id: "m\(Int(seconds))", authorID: "pal", createdAt: Date(timeIntervalSince1970: seconds), text: "x")
    }

    private func bill(_ seconds: Double) -> Bill {
        Bill(
            id: "b\(Int(seconds))", title: "x", date: CalendarDay(.now), currencyCode: "EUR", totalMinor: 1, paidBy: "pal",
            split: .equally, shares: ["pal": 1], createdBy: "pal", createdAt: Date(timeIntervalSince1970: seconds), updatedBy: "pal"
        )
    }

    @Test func mergesByTime() {
        var messages = PagedFeed<ChatMessage>(), bills = PagedFeed<Bill>()
        messages.show(latest: FeedPage(items: [message(1), message(3)], isFull: false, isFromCache: false))
        bills.show(latest: FeedPage(items: [bill(2), bill(4)], isFull: false, isFromCache: false))
        #expect(ChatEntry.merged(messages, bills).map(\.id) == ["m1", "b2", "m3", "b4"])
    }

    @Test func billsWaitForTheMessagesAroundThem() {
        var messages = PagedFeed<ChatMessage>(), bills = PagedFeed<Bill>()
        messages.show(latest: FeedPage(items: [message(10), message(11)], isFull: true, isFromCache: false))
        bills.show(latest: FeedPage(items: [bill(2), bill(12)], isFull: false, isFromCache: false))
        #expect(ChatEntry.merged(messages, bills).map(\.id) == ["m10", "m11", "b12"])
        messages.add(older: FeedPage(items: [message(1)], isFull: false, isFromCache: false), before: message(10))
        #expect(ChatEntry.merged(messages, bills).map(\.id) == ["m1", "b2", "m10", "m11", "b12"])
    }
}
