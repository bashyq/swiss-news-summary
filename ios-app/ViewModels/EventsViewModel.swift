import Foundation
import SwiftUI

// MARK: - Day Events

/// Events occurring on a specific calendar day.
struct DayEvents {
    let holidays: [Holiday]
    let schoolHolidays: [SchoolHoliday]
    let festivals: [CityEvent]
    let recurringActivities: [Activity]

    var isEmpty: Bool {
        holidays.isEmpty && schoolHolidays.isEmpty && festivals.isEmpty && recurringActivities.isEmpty
    }
}

// MARK: - Events ViewModel

/// ViewModel for the Events/Calendar view — manages calendar navigation, date selection,
/// and aggregation of holidays, school holidays, festivals, and recurring activities.
@Observable
final class EventsViewModel {

    // MARK: - Published State

    /// Currently selected date on the calendar (defaults to today)
    var selectedDate: Date? = Date()

    /// Current calendar month being displayed (1-12)
    var currentMonth: Int

    /// Current calendar year being displayed
    var currentYear: Int

    /// Active filter for the events list
    var eventFilter: String = "all"

    /// News response (provides holidays, school holidays, weather, trending)
    var newsData: NewsResponse?

    /// Activities response (provides city events/festivals, recurring activities)
    var activitiesData: ActivitiesResponse?

    /// Whether a network fetch is in progress
    var isLoading: Bool = false

    /// Human-readable error message if the last fetch failed
    var error: String?

    // MARK: - Init

    init() {
        let calendar = Calendar.current
        let today = Date()
        self.currentMonth = calendar.component(.month, from: today)
        self.currentYear = calendar.component(.year, from: today)
    }

    // MARK: - Computed Properties

    /// All dates in the currently displayed month
    var datesInMonth: [Date] {
        DateHelpers.datesInMonth(year: currentYear, month: currentMonth)
    }

    /// Number of blank cells before the first day of the month (Monday-based: Mon=0).
    ///
    /// `DateHelpers.firstWeekday` returns 1=Sunday, 2=Monday, ..., 7=Saturday.
    /// We convert to Monday-based offset: Mon=0, Tue=1, ..., Sun=6.
    var firstWeekdayOffset: Int {
        let weekday = DateHelpers.firstWeekday(year: currentYear, month: currentMonth)
        // Convert: Sunday(1)->6, Monday(2)->0, Tuesday(3)->1, ..., Saturday(7)->5
        return (weekday + 5) % 7
    }

    /// Formatted label for the current month and year (e.g., "February 2026")
    var monthYearLabel: String {
        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth
        components.day = 1
        guard let date = Calendar.current.date(from: components) else {
            return "\(currentMonth)/\(currentYear)"
        }
        return DateHelpers.monthYear(date)
    }

    /// All holidays from the news response
    var holidays: [Holiday] {
        newsData?.holidays ?? []
    }

    /// All school holidays from the news response
    var schoolHolidays: [SchoolHoliday] {
        newsData?.schoolHolidays ?? []
    }

    /// All city events/festivals from the activities response
    var cityEvents: [CityEvent] {
        activitiesData?.cityEvents ?? []
    }

    // MARK: - Calendar Navigation

    /// Navigate to the previous month
    func previousMonth() {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }
    }

    /// Navigate to the next month
    func nextMonth() {
        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }
    }

    // MARK: - Date Selection

    /// Select a date on the calendar. If the same date is tapped again, deselect it.
    func selectDate(_ date: Date) {
        if let current = selectedDate, DateHelpers.isSameDay(current, date) {
            selectedDate = nil
        } else {
            selectedDate = date
        }
    }

    // MARK: - Events for a Date

    /// Returns all events (holidays, school holidays, festivals, recurring activities) for a given date.
    func eventsForDate(_ date: Date) -> DayEvents {
        let dateISO = DateHelpers.toISO(date)

        // Holidays that fall on this date
        let matchingHolidays = holidays.filter { holiday in
            guard let holidayDate = holiday.date else { return false }
            return holidayDate == dateISO
        }

        // School holidays whose range overlaps this date
        let matchingSchoolHolidays = schoolHolidays.filter { sh in
            guard let start = sh.startDateParsed, let end = sh.endDateParsed else { return false }
            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: date)
            let shStart = calendar.startOfDay(for: start)
            let shEnd = calendar.startOfDay(for: end)
            return dayStart >= shStart && dayStart <= shEnd
        }

        // Festivals/city events that overlap this date
        let matchingFestivals = cityEvents.filter { $0.overlaps(with: date) }

        // Recurring activities available on this day of the week
        let allActivities = activitiesData?.activities ?? []
        let matchingRecurring = allActivities.filter { activity in
            guard activity.recurring != nil else { return false }
            return activity.isAvailable(on: date)
        }

        return DayEvents(
            holidays: matchingHolidays,
            schoolHolidays: matchingSchoolHolidays,
            festivals: matchingFestivals,
            recurringActivities: matchingRecurring
        )
    }

    // MARK: - Calendar Dot Colors

    /// Returns an array of dot colors to display under a calendar day.
    ///
    /// Color mapping:
    /// - `.purple` — holiday or festival
    /// - `.red` — holiday (public)
    /// - `.orange` (amber) — school holiday
    /// - `.blue` — recurring activity
    func dotColors(for date: Date) -> [Color] {
        let events = eventsForDate(date)
        var colors: [Color] = []

        if !events.holidays.isEmpty {
            colors.append(.red)
        }
        if !events.festivals.isEmpty {
            colors.append(.purple)
        }
        if !events.schoolHolidays.isEmpty {
            colors.append(.orange)
        }
        if !events.recurringActivities.isEmpty {
            colors.append(.blue)
        }

        return colors
    }

    // MARK: - Filtered Events List

    /// Returns all events filtered by the current `eventFilter`, as a heterogeneous array.
    ///
    /// Each element is one of: `Holiday`, `SchoolHoliday`, `CityEvent`, or `Activity`.
    /// The caller should use `as?` or `switch` to determine the type and render accordingly.
    ///
    /// Filter options: "all", "holidays", "schoolHolidays", "events", "recurring", "seasonal", "festivals"
    func filteredEvents(language: AppLanguage) -> [Any] {
        var results: [Any] = []

        let includeAll = eventFilter == "all"

        // Holidays
        if includeAll || eventFilter == "holidays" {
            results.append(contentsOf: holidays)
        }

        // School holidays
        if includeAll || eventFilter == "schoolHolidays" {
            results.append(contentsOf: schoolHolidays)
        }

        // City events / festivals
        if includeAll || eventFilter == "events" || eventFilter == "festivals" {
            results.append(contentsOf: cityEvents)
        }

        // Recurring activities
        if includeAll || eventFilter == "recurring" {
            let allActivities = activitiesData?.activities ?? []
            let recurring = allActivities.filter { $0.recurring != nil }
            results.append(contentsOf: recurring)
        }

        // Seasonal activities
        if includeAll || eventFilter == "seasonal" {
            let allActivities = activitiesData?.activities ?? []
            let seasonal = allActivities.filter { $0.season != nil && $0.isCurrentSeason }
            results.append(contentsOf: seasonal)
        }

        return results
    }

    // MARK: - Loading

    /// Load both news and activities data for the events calendar.
    ///
    /// The events view needs data from both endpoints:
    /// - News: holidays, school holidays, weather, trending
    /// - Activities: city events/festivals, recurring activities
    ///
    /// Strategy: show cached data immediately, then fetch fresh data in the background.
    @MainActor
    func loadData(city: City, language: AppLanguage) async {
        let newsCacheKey = CacheKey.news(city: city, language: language)
        let activitiesCacheKey = CacheKey.activities(city: city)

        // 1. Show cached data immediately
        let cachedNews: NewsResponse? = await CacheManager.shared.get(
            NewsResponse.self,
            key: newsCacheKey,
            ttl: .news
        )
        if let cachedNews {
            self.newsData = cachedNews
        }

        let cachedActivities: ActivitiesResponse? = await CacheManager.shared.get(
            ActivitiesResponse.self,
            key: activitiesCacheKey,
            ttl: .activities
        )
        if let cachedActivities {
            self.activitiesData = cachedActivities
        }

        // 2. Fetch fresh data from both endpoints in parallel
        isLoading = true
        error = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor [weak self] in
                do {
                    let response = try await APIClient.shared.fetchNews(
                        city: city,
                        language: language
                    )
                    self?.newsData = response
                    await CacheManager.shared.set(response, key: newsCacheKey)
                } catch {
                    if self?.newsData == nil {
                        self?.error = error.localizedDescription
                    }
                }
            }

            group.addTask { @MainActor [weak self] in
                do {
                    let response = try await APIClient.shared.fetchActivities(
                        city: city,
                        language: language
                    )
                    self?.activitiesData = response
                    await CacheManager.shared.set(response, key: activitiesCacheKey)
                } catch {
                    if self?.activitiesData == nil && self?.error == nil {
                        self?.error = error.localizedDescription
                    }
                }
            }
        }

        isLoading = false
    }
}
