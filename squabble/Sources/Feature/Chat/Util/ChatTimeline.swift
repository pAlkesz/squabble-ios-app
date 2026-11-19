import Foundation

/// Turns messages (oldest first) into the rows the chat shows: a day header whenever the
/// day changes, and each message marked with whether it starts or ends a run from one
/// author, so names and avatars show once per run.
nonisolated enum ChatTimeline {
    enum Row: Identifiable, Equatable {
        case day(Date)
        case message(ChatMessage, startsRun: Bool, endsRun: Bool)

        var id: String {
            switch self {
            case .day(let date): "day-\(date.timeIntervalSinceReferenceDate)"
            case .message(let message, _, _): message.id
            }
        }
    }

    /// Messages further apart than this start a new run even from the same author.
    static let runGap: TimeInterval = 5 * 60

    static func rows(for messages: [ChatMessage], now: Date = .now, calendar: Calendar = .current) -> [Row] {
        var rows: [Row] = []
        for (index, message) in messages.enumerated() {
            let date = message.createdAt ?? now
            let previous = index > 0 ? messages[index - 1] : nil
            let next = index + 1 < messages.count ? messages[index + 1] : nil
            let previousDate = previous.map { $0.createdAt ?? now }
            if previousDate.map({ !calendar.isDate($0, inSameDayAs: date) }) ?? true {
                rows.append(.day(calendar.startOfDay(for: date)))
            }
            rows.append(.message(
                message,
                startsRun: !continues(previous, into: message, now: now, calendar: calendar),
                endsRun: !continues(message, into: next, now: now, calendar: calendar)
            ))
        }
        return rows
    }

    private static func continues(_ first: ChatMessage?, into second: ChatMessage?, now: Date, calendar: Calendar) -> Bool {
        guard let first, let second, first.authorID == second.authorID else { return false }
        let a = first.createdAt ?? now, b = second.createdAt ?? now
        return calendar.isDate(a, inSameDayAs: b) && b.timeIntervalSince(a) <= runGap
    }

    /// "Today", "Yesterday", the weekday within the last week, then the date.
    static func dayTitle(for day: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return String(localized: "Today", comment: "Chat: day header for today's messages.")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return String(localized: "Yesterday", comment: "Chat: day header for yesterday's messages.")
        }
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)), day >= weekAgo {
            return day.formatted(style.weekday(.wide))
        }
        if calendar.isDate(day, equalTo: now, toGranularity: .year) {
            return day.formatted(style.month(.abbreviated).day())
        }
        return day.formatted(style.year().month(.abbreviated).day())
    }
}
