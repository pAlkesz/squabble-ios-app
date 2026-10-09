/// Handles to offer under the handle field, built from the display name like the first
/// suggestion. A fixed set of patterns rather than random digits, so the same name always
/// gets the same suggestions.
nonisolated enum HandleSuggestions {
    private static let patterns: [(prefix: String, suffix: String)] = [
        ("", "2"),
        ("", "_pays"),
        ("the_", ""),
        ("", "_owed"),
        ("", "3"),
    ]

    /// The plain handle for the name first, then its decorated variants.
    static func candidates(fromName name: String) -> [Handle] {
        guard let base = try? Handle(validating: Handle.suggestion(from: name)) else { return [] }
        return [base] + candidates(for: base)
    }

    static func candidates(for handle: Handle) -> [Handle] {
        var seen: Set<Handle> = [handle]
        var result: [Handle] = []
        for pattern in patterns {
            // Trim the base so the decorated handle still fits the length limit.
            let room = Handle.lengthRange.upperBound - pattern.prefix.count - pattern.suffix.count
            var base = String(handle.rawValue.prefix(room))
            while base.hasSuffix("_") { base.removeLast() }
            guard let candidate = try? Handle(validating: pattern.prefix + base + pattern.suffix),
                  seen.insert(candidate).inserted
            else { continue }
            result.append(candidate)
        }
        return result
    }
}
