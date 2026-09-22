import Foundation

nonisolated extension Avatar {
    init?(firestoreData data: [String: Any]) {
        switch data["kind"] as? String {
        case "preset":
            guard let preset = (data["preset"] as? String).flatMap(AvatarPreset.init(rawValue:)) else { return nil }
            self = .preset(preset)
        case "photo":
            guard let path = data["path"] as? String,
                  let url = (data["url"] as? String).flatMap(URL.init(string:))
            else { return nil }
            self = .photo(path: path, url: url)
        default:
            return nil
        }
    }

    var firestoreData: [String: Any] {
        switch self {
        case .preset(let preset):
            ["kind": "preset", "preset": preset.rawValue]
        case .photo(let path, let url):
            ["kind": "photo", "path": path, "url": url.absoluteString]
        }
    }
}
