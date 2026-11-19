import Foundation

/// How a list row dates its last activity, as messaging apps do: the time today, the
/// weekday within the last week, then the date, with the year only once it's not this one.
nonisolated enum ActivityDate {
    static func text(for date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(style.hour().minute())
        }
        let startOfToday = calendar.startOfDay(for: now)
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday), date >= weekAgo, date < startOfToday {
            return date.formatted(style.weekday(.abbreviated))
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(style.month(.abbreviated).day())
        }
        return date.formatted(style.year().month(.abbreviated).day())
    }
}
