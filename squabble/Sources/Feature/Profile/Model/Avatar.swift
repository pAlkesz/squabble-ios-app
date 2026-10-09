import Foundation

nonisolated enum Avatar: Equatable, Sendable {
    /// The plain bird. Stored as kind "preset", its original name.
    case preset(AvatarColor)
    case persona(AvatarPersona, AvatarColor)
    /// `path` is the storage object (needed to delete it); `url` is what gets displayed.
    case photo(path: String, url: URL)

    var photoPath: String? {
        if case .photo(let path, _) = self { return path }
        return nil
    }
}
