import Foundation
@testable import squabble

final class FakeBillRepository: BillRepository, @unchecked Sendable {
    var latest: [FeedPage<Bill>] = [FeedPage(items: [], isFull: false, isFromCache: false)]
    var olderPages: [FeedPage<Bill>] = []
    private(set) var added: [Bill] = []
    private(set) var updated: [Bill] = []
    private(set) var deleted: [String] = []

    func latestBills(in groupID: String, limit: Int) -> AsyncThrowingStream<FeedPage<Bill>, Error> {
        let pages = latest
        return AsyncThrowingStream { continuation in
            pages.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func bills(in groupID: String, before date: Date, limit: Int) async throws -> FeedPage<Bill> {
        olderPages.isEmpty ? FeedPage(items: [], isFull: false, isFromCache: false) : olderPages.removeFirst()
    }

    func add(_ bill: Bill, in groupID: String) throws { added.append(bill) }
    func update(_ bill: Bill, in groupID: String) throws { updated.append(bill) }
    func delete(_ bill: Bill, by uid: String, in groupID: String) throws { deleted.append(bill.id) }
}
