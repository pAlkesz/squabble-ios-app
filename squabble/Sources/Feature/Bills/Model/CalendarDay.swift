import Foundation

/// A day without a time, stored as "2026-11-25": a dinner stays on its day wherever it's read.
nonisolated struct CalendarDay: Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(_ date: Date, calendar: Calendar = .current) {
        let parts = Self.gregorian(like: calendar).dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 1970
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard rawValue.count == 10, parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        (year, month, day) = (parts[0], parts[1], parts[2])
    }

    var rawValue: String {
        "\(Self.padded(year, 4))-\(Self.padded(month, 2))-\(Self.padded(day, 2))"
    }

    /// Midday, clear of the hour that daylight saving can skip.
    func date(calendar: Calendar = .current) -> Date {
        Self.gregorian(like: calendar).date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }

    /// The stored day is Gregorian whatever calendar the phone uses.
    private static func gregorian(like calendar: Calendar) -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian
    }

    private static func padded(_ number: Int, _ width: Int) -> String {
        let digits = String(number)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
