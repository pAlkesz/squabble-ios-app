import Foundation

nonisolated enum Avatar: Equatable, Sendable {
    case preset(AvatarPreset)
    /// `path` is the storage object (needed to delete it); `url` is what gets displayed.
    case photo(path: String, url: URL)

    var photoPath: String? {
        if case .photo(let path, _) = self { return path }
        return nil
    }
}
