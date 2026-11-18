import Foundation

/// A squabble's picture, always shown as a circle: an emoji on a coloured disc, or a photo.
nonisolated enum SquabbleImage: Equatable, Sendable {
    case emoji(String, AvatarColor)
    /// `path` is the storage object (needed to delete it); `url` is what gets displayed.
    case photo(path: String, url: URL)

    /// Emojis offered when there's no photo: the presets' own, then a petty assortment.
    /// The first one is the fallback for a squabble with no readable image.
    static let emojis: [String] = [
        "🧾", "💸", "🏝️", "🛋️", "🍝", "🎉", "👨‍👩‍👧", "💑",
        "🍕", "🍻", "🥡", "🍣", "☕️", "🎂", "🎳", "🎮",
        "⛷️", "🏕️", "🚗", "✈️", "🧳", "🐦", "🙄", "🤬",
    ]

    /// Stable for a given squabble, like a person's fallback bird.
    static func `default`(for groupID: String) -> SquabbleImage {
        .emoji(emojis[0], .default(for: groupID))
    }

    static func random() -> SquabbleImage {
        .emoji(emojis.randomElement() ?? emojis[0], AvatarColor.allCases.randomElement() ?? .meadow)
    }

    var photoPath: String? {
        if case .photo(let path, _) = self { return path }
        return nil
    }
}
