import Foundation

/// Date parsing and formatting helpers
enum DateHelpers {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private static let isoDateTimeFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// Parse ISO date string "2026-02-21"
    static func parseISO(_ string: String) -> Date? {
        isoFormatter.date(from: string)
    }

    /// Parse ISO datetime string
    static func parseISODateTime(_ string: String) -> Date? {
        isoDateTimeFormatter.date(from: string)
    }

    /// Format date for display
    static func display(_ date: Date) -> String {
        displayFormatter.string(from: date)
    }

    /// Day name (e.g., "Friday")
    static func dayName(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// Short day name (e.g., "Fri")
    static func shortDayName(_ date: Date) -> String {
        shortDayFormatter.string(from: date)
    }

    /// Month and year (e.g., "February 2026")
    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    /// ISO string from date
    static func toISO(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// Get weekend dates (Friday, Saturday, Sunday) from today
    static func weekendDates() -> (friday: Date, saturday: Date, sunday: Date)? {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)

        // Days until Friday (6)
        let daysUntilFriday: Int
        if weekday <= 6 {
            daysUntilFriday = 6 - weekday
        } else { // Sunday
            daysUntilFriday = 6
        }

        guard let friday = cal.date(byAdding: .day, value: daysUntilFriday, to: today),
              let saturday = cal.date(byAdding: .day, value: 1, to: friday),
              let sunday = cal.date(byAdding: .day, value: 2, to: friday) else {
            return nil
        }

        return (friday, saturday, sunday)
    }

    /// Get all dates in a month for calendar grid
    static func datesInMonth(year: Int, month: Int) -> [Date] {
        let cal = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let firstDay = cal.date(from: components),
              let range = cal.range(of: .day, in: .month, for: firstDay) else {
            return []
        }

        return range.compactMap { day -> Date? in
            var dc = DateComponents()
            dc.year = year
            dc.month = month
            dc.day = day
            return cal.date(from: dc)
        }
    }

    /// First weekday of a month (1=Sunday, 2=Monday, etc.)
    static func firstWeekday(year: Int, month: Int) -> Int {
        let cal = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = cal.date(from: components) else { return 1 }
        return cal.component(.weekday, from: date)
    }

    /// Check if two dates are the same day
    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    /// Check if date is today
    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Time ago string
    static func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }
}
