import Foundation

nonisolated extension Avatar {
    init?(firestoreData data: [String: Any]) {
        switch data["kind"] as? String {
        case "preset":
            guard let preset = (data["preset"] as? String).flatMap(AvatarColor.init(rawValue:)) else { return nil }
            self = .preset(preset)
        case "persona":
            // An app older than the persona fails here and falls back to the bird.
            guard let persona = (data["persona"] as? String).flatMap(AvatarPersona.init(rawValue:)),
                  let color = (data["color"] as? String).flatMap(AvatarColor.init(rawValue:))
            else { return nil }
            self = .persona(persona, color)
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
        case .persona(let persona, let color):
            ["kind": "persona", "persona": persona.rawValue, "color": color.rawValue]
        case .photo(let path, let url):
            ["kind": "photo", "path": path, "url": url.absoluteString]
        }
    }
}
