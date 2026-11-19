import Foundation
import Testing
@testable import squabble

struct ActivityDateTests {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func text(_ date: Date) -> String {
        // Thursday 19 November 2026, afternoon.
        ActivityDate.text(for: date, now: self.date(2026, 11, 19, 15), calendar: calendar, locale: locale)
    }

    @Test func todayShowsTheTime() {
        #expect(text(date(2026, 11, 19, 9)).contains("9"))
        #expect(text(date(2026, 11, 19, 9)).contains("00"))
    }

    @Test func theLastWeekShowsTheWeekday() {
        #expect(text(date(2026, 11, 17)) == "Tue")
        #expect(text(date(2026, 11, 13)) == "Fri")
    }

    @Test func olderThisYearShowsMonthAndDay() {
        #expect(text(date(2026, 11, 12)) == "Nov 12")
        #expect(text(date(2026, 10, 30)) == "Oct 30")
    }

    @Test func earlierYearsShowTheYear() {
        #expect(text(date(2025, 12, 31)) == "Dec 31, 2025")
    }
}
