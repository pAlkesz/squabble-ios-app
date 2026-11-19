import Foundation

/// A squabble's picture, always shown as a circle: a drawing on a gradient, or a photo.
nonisolated enum SquabbleImage: Equatable, Sendable {
    case artwork(SquabbleArtwork, SquabbleBackground)
    /// `path` is the storage object (needed to delete it); `url` is what gets displayed.
    case photo(path: String, url: URL)
    /// What squabbles got before drawings (Nov 2026). Still shown for those; never offered.
    case emoji(String, AvatarColor)

    /// Stable for a given squabble, like a person's fallback bird.
    static func `default`(for groupID: String) -> SquabbleImage {
        .artwork(.trio, .default(for: groupID))
    }

    static func random() -> SquabbleImage {
        .artwork(SquabbleArtwork.allCases.randomElement() ?? .trio, SquabbleBackground.allCases.randomElement() ?? .mint)
    }

    var photoPath: String? {
        if case .photo(let path, _) = self { return path }
        return nil
    }
}
