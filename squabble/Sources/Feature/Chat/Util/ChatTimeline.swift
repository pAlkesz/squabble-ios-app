import Foundation

/// Turns entries (oldest first) into the rows the chat shows: a day header whenever the
/// day changes, and each message and bill marked with whether it starts or ends a run from one
/// author, so the gap above, the avatar and the bubble's tail show once per run. Messages and
/// bills share runs; a deleted bill, which isn't a bubble, breaks them.
nonisolated enum ChatTimeline {
    enum Row: Identifiable, Equatable {
        case day(Date)
        /// `showsName`: the first message after anything that isn't the same author's message,
        /// a bill included, since a bill card doesn't name who added it.
        case message(ChatMessage, startsRun: Bool, endsRun: Bool, showsName: Bool)
        case bill(Bill, startsRun: Bool, endsRun: Bool)

        var id: String {
            switch self {
            case .day(let date): "day-\(date.timeIntervalSinceReferenceDate)"
            case .message(let message, _, _, _): message.id
            case .bill(let bill, _, _): bill.id
            }
        }
    }

    /// Messages further apart than this start a new run even from the same author.
    static let runGap: TimeInterval = 5 * 60

    static func rows(for entries: [ChatEntry], now: Date = .now, calendar: Calendar = .current) -> [Row] {
        var rows: [Row] = []
        for (index, entry) in entries.enumerated() {
            let date = entry.createdAt ?? now
            let previous = index > 0 ? entries[index - 1] : nil
            let next = index + 1 < entries.count ? entries[index + 1] : nil
            let previousDate = previous.map { $0.createdAt ?? now }
            if previousDate.map({ !calendar.isDate($0, inSameDayAs: date) }) ?? true {
                rows.append(.day(calendar.startOfDay(for: date)))
            }
            let startsRun = !continues(previous, into: entry, now: now, calendar: calendar)
            let endsRun = !continues(entry, into: next, now: now, calendar: calendar)
            switch entry {
            case .message(let message):
                let followsOwnMessage = if case .message = previous { !startsRun } else { false }
                rows.append(.message(message, startsRun: startsRun, endsRun: endsRun, showsName: !followsOwnMessage))
            case .bill(let bill):
                rows.append(.bill(bill, startsRun: startsRun, endsRun: endsRun))
            }
        }
        return rows
    }

    private static func continues(_ first: ChatEntry?, into second: ChatEntry?, now: Date, calendar: Calendar) -> Bool {
        guard let first, let second, let author = author(of: first), author == self.author(of: second) else { return false }
        let a = first.createdAt ?? now, b = second.createdAt ?? now
        return calendar.isDate(a, inSameDayAs: b) && b.timeIntervalSince(a) <= runGap
    }

    /// Who a bubble belongs to; nil for a deleted bill, which is a line, not a bubble.
    private static func author(of entry: ChatEntry) -> String? {
        switch entry {
        case .message(let message): message.authorID
        case .bill(let bill): bill.isDeleted ? nil : bill.createdBy
        }
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
