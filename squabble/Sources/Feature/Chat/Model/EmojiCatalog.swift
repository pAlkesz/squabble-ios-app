import Foundation

/// Every emoji the reaction picker offers, in Unicode's groups and order, with their English
/// names for search. Read from `Emoji.json`, generated from Unicode's emoji-test.txt (see
/// THIRD_PARTY_NOTICES.md); skin-tone variants are left out.
nonisolated struct EmojiCatalog: Sendable {
    struct Emoji: Hashable, Sendable {
        let character: String
        let name: String
    }

    struct Group: Identifiable, Sendable {
        /// Unicode's group name, in English.
        let id: String
        let emoji: [Emoji]
    }

    let groups: [Group]

    static let shared = EmojiCatalog(bundle: .main)

    init(groups: [Group]) {
        self.groups = groups
    }

    init(bundle: Bundle) {
        guard let url = bundle.url(forResource: "Emoji", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            self.init(groups: [])
            return
        }
        self.init(groups: file.groups.map { group in
            Group(id: group.name, emoji: group.emoji.compactMap { pair in
                pair.count == 2 ? Emoji(character: pair[0], name: pair[1]) : nil
            })
        })
    }

    /// Groups holding only the emoji whose name has every word typed, in any order.
    func matching(_ query: String) -> [Group] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return groups }
        return groups.compactMap { group in
            let found = group.emoji.filter { emoji in
                emoji.character == query || words.allSatisfy { emoji.name.localizedCaseInsensitiveContains($0) }
            }
            return found.isEmpty ? nil : Group(id: group.id, emoji: found)
        }
    }

    private struct File: Decodable {
        struct Group: Decodable {
            let name: String
            let emoji: [[String]]
        }

        let groups: [Group]
    }
}
