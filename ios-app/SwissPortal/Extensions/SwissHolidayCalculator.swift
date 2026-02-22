import Foundation

/// Computes upcoming Swiss holidays with dates and days-until values.
/// Extracted from SettingsView to keep it focused on UI layout.
enum SwissHolidayCalculator {

    /// Returns the next 5 upcoming Swiss holidays sorted by days until.
    static func upcomingHolidays() -> [Holiday] {
        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)

        let allHolidays: [(name: String, nameDE: String, month: Int, day: Int)] = [
            ("New Year's Day", "Neujahr", 1, 1),
            ("Berchtoldstag", "Berchtoldstag", 1, 2),
            ("Good Friday", "Karfreitag", 0, 0),
            ("Easter Monday", "Ostermontag", 0, 0),
            ("Labour Day", "Tag der Arbeit", 5, 1),
            ("Ascension Day", "Auffahrt", 0, 0),
            ("Whit Monday", "Pfingstmontag", 0, 0),
            ("Swiss National Day", "Bundesfeiertag", 8, 1),
            ("Christmas Day", "Weihnachten", 12, 25),
            ("St. Stephen's Day", "Stephanstag", 12, 26),
        ]

        let easterDate = calculateEaster(year: year)
        var holidays: [Holiday] = []

        for h in allHolidays {
            switch h.name {
            case "Good Friday":
                if let date = calendar.date(byAdding: .day, value: -2, to: easterDate) {
                    let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                    if daysUntil >= 0 {
                        holidays.append(Holiday(
                            name: h.name, nameDE: h.nameDE, daysUntil: daysUntil,
                            date: DateHelpers.toISO(date)
                        ))
                    }
                }
            case "Easter Monday":
                if let date = calendar.date(byAdding: .day, value: 1, to: easterDate) {
                    let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                    if daysUntil >= 0 {
                        holidays.append(Holiday(
                            name: h.name, nameDE: h.nameDE, daysUntil: daysUntil,
                            date: DateHelpers.toISO(date)
                        ))
                    }
                }
            case "Ascension Day":
                if let date = calendar.date(byAdding: .day, value: 39, to: easterDate) {
                    let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                    if daysUntil >= 0 {
                        holidays.append(Holiday(
                            name: h.name, nameDE: h.nameDE, daysUntil: daysUntil,
                            date: DateHelpers.toISO(date)
                        ))
                    }
                }
            case "Whit Monday":
                if let date = calendar.date(byAdding: .day, value: 50, to: easterDate) {
                    let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                    if daysUntil >= 0 {
                        holidays.append(Holiday(
                            name: h.name, nameDE: h.nameDE, daysUntil: daysUntil,
                            date: DateHelpers.toISO(date)
                        ))
                    }
                }
            default:
                let dateComponents = DateComponents(year: year, month: h.month, day: h.day)
                guard let date = calendar.date(from: dateComponents) else { continue }
                let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0

                if daysUntil < 0 {
                    let nextYearComponents = DateComponents(year: year + 1, month: h.month, day: h.day)
                    guard let nextDate = calendar.date(from: nextYearComponents) else { continue }
                    let nextDaysUntil = calendar.dateComponents([.day], from: today, to: nextDate).day ?? 0
                    holidays.append(Holiday(
                        name: h.name, nameDE: h.nameDE, daysUntil: nextDaysUntil,
                        date: DateHelpers.toISO(nextDate)
                    ))
                } else {
                    holidays.append(Holiday(
                        name: h.name, nameDE: h.nameDE, daysUntil: daysUntil,
                        date: DateHelpers.toISO(date)
                    ))
                }
            }
        }

        return holidays
            .sorted { $0.daysUntil < $1.daysUntil }
            .prefix(5)
            .map { $0 }
    }

    /// Anonymous Gregorian Easter computation (Computus)
    private static func calculateEaster(year: Int) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }
}
