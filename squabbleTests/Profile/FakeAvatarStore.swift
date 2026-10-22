import Foundation
@testable import squabble

nonisolated final class FakeAvatarStore: AvatarStore, @unchecked Sendable {
    private(set) var uploads: [String: [Data]] = [:]
    private(set) var deletedUIDs: [String] = []
    private(set) var deletedPaths: [String] = []

    func upload(_ jpeg: Data, for uid: String) async throws -> Avatar {
        uploads[uid, default: []].append(jpeg)
        let path = "avatars/\(uid)/\(uploads[uid, default: []].count).jpg"
        return .photo(path: path, url: URL(string: "https://example.com/\(path)")!)
    }

    func deleteAll(for uid: String, keeping: String?) async throws {
        if keeping == nil { deletedUIDs.append(uid) }
        let paths = (uploads[uid] ?? []).indices.map { "avatars/\(uid)/\($0 + 1).jpg" }
        deletedPaths += paths.filter { $0 != keeping }
    }
}
