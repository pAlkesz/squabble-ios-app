import Foundation

/// A squabble's bills. Writes land in the local cache straight away and sync later, and each
/// marks the squabble as just active.
nonisolated protocol BillRepository: Sendable {
    /// The latest `limit` bills by when they were added, oldest first, then every change.
    func latestBills(in groupID: String, limit: Int) -> AsyncThrowingStream<FeedPage<Bill>, Error>
    func bills(in groupID: String, before date: Date, limit: Int) async throws -> FeedPage<Bill>
    func add(_ bill: Bill, in groupID: String) throws
    func update(_ bill: Bill, in groupID: String) throws
    func delete(_ bill: Bill, by uid: String, in groupID: String) throws
}
