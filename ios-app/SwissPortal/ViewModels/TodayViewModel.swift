import Foundation
import CoreLocation
import WidgetKit

/// State of the agenda composition pipeline.
enum AgendaState: Equatable {
    case idle
    case loading
    case loaded
    case fallback  // using TemplateEngine
    case error(String)
}

/// ViewModel for the Today tab — orchestrates parallel loading of news, activities,
/// and lunch data, then composes a day agenda via AI or template fallback.
@Observable
final class TodayViewModel {

    // MARK: - Raw Data

    var newsData: NewsResponse?
    var activitiesData: ActivitiesResponse?
    var lunchData: LunchResponse?

    var isLoading = false
    var error: String?

    // MARK: - Agenda

    /// Internal storage: multiple agendas keyed by ISO date string.
    private var _agendas: [String: DayAgenda] = [:]
    private var _agendaStates: [String: AgendaState] = [:]

    /// The currently selected plan day (today by default, weekend days in weekend mode).
    var selectedPlanDay: PlanDay = .today

    /// Whether the user activated weekend planning mode.
    var isWeekendMode: Bool = false

    /// Computed bridge — all existing code reads/writes `agenda` unchanged.
    var agenda: DayAgenda? {
        get { _agendas[selectedPlanDay.isoDate] }
        set { _agendas[selectedPlanDay.isoDate] = newValue }
    }

    var agendaState: AgendaState {
        get { _agendaStates[selectedPlanDay.isoDate] ?? .idle }
        set { _agendaStates[selectedPlanDay.isoDate] = newValue }
    }

    var agendaMode: AgendaMode = .browsing {
        didSet { persistAgendaMode() }
    }

    /// True on Friday 8PM+ or Saturday (before Sunday).
    var canPlanWeekend: Bool {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now) // 1=Sun, 7=Sat
        let hour = cal.component(.hour, from: now)
        // Friday (6) after 8 PM or Saturday (7) all day
        return (weekday == 6 && hour >= 20) || weekday == 7
    }

    /// Available plan days based on current time/mode.
    var availablePlanDays: [PlanDay] {
        if isWeekendMode {
            return [.saturday, .sunday]
        }
        if isNextDayMode {
            return [.tomorrow]
        }
        return [.today]
    }

    // MARK: - Convenience

    var weather: Weather? { newsData?.weather }

    /// Whether to prefer indoor activities based on weather.
    /// True when temperature is below 10°C (cold) OR when it's raining/snowing.
    var preferIndoor: Bool {
        guard let w = weather else { return false }
        let rainCodes: Set<Int> = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
        return w.temperature < 10 || rainCodes.contains(w.weatherCode)
    }

    /// Full bad-weather-home mode: cold AND heavy rain/snow.
    /// Triggers stay-home agenda with home activities (baking, movie, craft) + single outing.
    var isBadWeatherDay: Bool {
        guard let w = weather else { return false }
        let heavyCodes: Set<Int> = [65, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
        return w.temperature < 10 && heavyCodes.contains(w.weatherCode)
    }

    /// After 8 PM, plan for tomorrow instead of today
    var isNextDayMode: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 20
    }

    /// The date we're planning for (today, or tomorrow if after 8 PM)
    var targetDate: Date {
        if isNextDayMode {
            return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        return Date()
    }

    private let recentlyShownStore = RecentlyShownStore()
    private let agendaCache = AgendaCache.shared

    // MARK: - Loading

    /// Load all three data sources in parallel with cache-first strategy,
    /// then compose the day agenda.
    @MainActor
    func loadAll(city: City, language: AppLanguage, forceRefresh: Bool = false) async {
        let newsCacheKey = CacheKey.news(city: city, language: language)
        let activitiesCacheKey = CacheKey.activities(city: city)
        let lunchCacheKey = CacheKey.lunch(city: city)

        // 1. Show cached data immediately
        if !forceRefresh {
            if let cached: NewsResponse = await CacheManager.shared.get(
                NewsResponse.self, key: newsCacheKey, ttl: .news
            ) {
                self.newsData = cached
            }
            if let cached: ActivitiesResponse = await CacheManager.shared.get(
                ActivitiesResponse.self, key: activitiesCacheKey, ttl: .activities
            ) {
                self.activitiesData = cached
            }
            if let cached: LunchResponse = await CacheManager.shared.get(
                LunchResponse.self, key: lunchCacheKey, ttl: .lunch
            ) {
                self.lunchData = cached
            }
        }

        isLoading = true
        error = nil

        // 2. Fetch fresh data in parallel
        async let newsTask = APIClient.shared.fetchNews(
            city: city, language: language, forceRefresh: forceRefresh
        )
        async let activitiesTask = APIClient.shared.fetchActivities(
            city: city, language: language
        )
        async let lunchTask = APIClient.shared.fetchLunch(
            city: city, language: language
        )

        // News
        do {
            let news = try await newsTask
            self.newsData = news
            await CacheManager.shared.set(news, key: newsCacheKey)
            LiveActivityManager.shared.update(
                transport: news.transport, cityName: news.city.name
            )
        } catch {
            if self.newsData == nil {
                let stale: NewsResponse? = await CacheManager.shared.getStale(
                    NewsResponse.self, key: newsCacheKey
                )
                if let stale { self.newsData = stale }
                else { self.error = error.localizedDescription }
            }
        }

        // Activities
        do {
            let activities = try await activitiesTask
            self.activitiesData = activities
            await CacheManager.shared.set(activities, key: activitiesCacheKey)
        } catch {
            if self.activitiesData == nil {
                let stale: ActivitiesResponse? = await CacheManager.shared.getStale(
                    ActivitiesResponse.self, key: activitiesCacheKey
                )
                if let stale { self.activitiesData = stale }
            }
        }

        // Lunch
        do {
            let lunch = try await lunchTask
            self.lunchData = lunch
            await CacheManager.shared.set(lunch, key: lunchCacheKey)
        } catch {
            if self.lunchData == nil {
                let stale: LunchResponse? = await CacheManager.shared.getStale(
                    LunchResponse.self, key: lunchCacheKey
                )
                if let stale { self.lunchData = stale }
            }
        }

        isLoading = false

        // 3. Set selectedPlanDay based on current time (if not in weekend mode)
        if !isWeekendMode {
            selectedPlanDay = isNextDayMode ? .tomorrow : .today
        }

        // 4. Compose agenda after data is loaded
        await composeAgenda(city: city, language: language, session: FamilySession.load())
    }

    // MARK: - Agenda Composition

    /// Compose the day agenda: cache check → Worker API → template fallback.
    /// After 8 PM, plans for tomorrow instead of today.
    @MainActor
    func composeAgenda(city: City, language: AppLanguage, session: FamilySession) async {
        await composeAgendaForDate(
            dateISO: Self.dateISO(targetDate),
            city: city,
            language: language,
            session: session,
            extraRecentlyShown: [],
            useAnchors: true
        )
    }

    /// Compose an agenda for a specific date. Generalized for multi-day support.
    @MainActor
    private func composeAgendaForDate(
        dateISO: String,
        city: City,
        language: AppLanguage,
        session: FamilySession,
        extraRecentlyShown: [String],
        useAnchors: Bool
    ) async {
        let currentAnchors = useAnchors ? AnchorStore.shared.anchors() : []
        let combinedRecent = Array(recentlyShownStore.recentlyShownIds()) + extraRecentlyShown
        let isNotToday = dateISO != Self.dateISO(Date())

        // 1. Check cache (keyed by date + city + session)
        // Skip cache if anchors changed since last compose
        if currentAnchors.isEmpty,
           let cachedData = await agendaCache.get(date: dateISO, city: city.id, sessionHash: session.sessionHash),
           let cached = try? JSONDecoder().decode(DayAgenda.self, from: cachedData) {
            _agendas[dateISO] = cached
            _agendaStates[dateISO] = .loaded
            syncAgendaToWidget()
            restoreAgendaMode()
            return
        }

        _agendaStates[dateISO] = .loading

        // 2. Try Worker API
        do {
            let result = try await APIClient.shared.fetchAgenda(
                city: city,
                language: language,
                session: session,
                weatherCode: weather?.weatherCode,
                temperature: weather.map { Int($0.temperature) },
                recentlyShown: combinedRecent,
                anchors: currentAnchors,
                targetDate: isNotToday ? dateISO : nil
            )
            _agendas[dateISO] = result
            _agendaStates[dateISO] = .loaded
            syncAgendaToWidget()
            restoreAgendaMode()

            // Cache the result (only when no anchors — anchor agendas are ephemeral)
            if currentAnchors.isEmpty, let encoded = try? JSONEncoder().encode(result) {
                await agendaCache.store(encoded, date: dateISO, city: city.id, sessionHash: session.sessionHash)
            }

            // Record shown venues
            for slot in result.slots {
                if let venueId = slot.venueId {
                    recentlyShownStore.recordShown(venueId: venueId)
                }
            }
            return
        } catch {
            #if DEBUG
            print("⚠️ Agenda API failed, falling back to template: \(error.localizedDescription)")
            #endif
        }

        // 3. Template engine fallback (only for current selectedPlanDay)
        buildTemplateFallback(session: session, language: language, dateISO: dateISO)
    }

    /// Compose weekend agendas (Saturday + Sunday) in sequence.
    /// Sunday avoids repeating Saturday's venues.
    @MainActor
    func composeWeekend(city: City, language: AppLanguage, session: FamilySession) async {
        isWeekendMode = true
        selectedPlanDay = .saturday

        let satISO = PlanDay.saturday.isoDate
        let sunISO = PlanDay.sunday.isoDate

        // Compose Saturday first
        await composeAgendaForDate(
            dateISO: satISO,
            city: city,
            language: language,
            session: session,
            extraRecentlyShown: [],
            useAnchors: false  // Anchors are today-only
        )

        // Collect Saturday's venue IDs to avoid repeats on Sunday
        let satVenueIds = (_agendas[satISO]?.slots ?? []).compactMap(\.venueId)

        // Compose Sunday with Saturday's venues as extra recently shown
        await composeAgendaForDate(
            dateISO: sunISO,
            city: city,
            language: language,
            session: session,
            extraRecentlyShown: satVenueIds,
            useAnchors: false
        )

        // Show Saturday first
        selectedPlanDay = .saturday
    }

    /// Rebuild weekend agendas (invalidate cache, recompose both days).
    @MainActor
    func rebuildWeekend(city: City, language: AppLanguage, session: FamilySession) async {
        await agendaCache.invalidate()
        recentlyShownStore.clear()
        let satISO = PlanDay.saturday.isoDate
        let sunISO = PlanDay.sunday.isoDate
        _agendas[satISO] = nil
        _agendas[sunISO] = nil
        _agendaStates[satISO] = .idle
        _agendaStates[sunISO] = .idle
        agendaMode = .browsing
        await composeWeekend(city: city, language: language, session: session)
    }

    /// Exit weekend mode and return to today/tomorrow planning.
    @MainActor
    func exitWeekendMode() {
        isWeekendMode = false
        selectedPlanDay = isNextDayMode ? .tomorrow : .today
    }

    /// Invalidate cache and recompose the agenda.
    @MainActor
    func rebuildAgenda(city: City, language: AppLanguage, session: FamilySession) async {
        if isWeekendMode {
            await rebuildWeekend(city: city, language: language, session: session)
            return
        }
        await agendaCache.invalidate()
        recentlyShownStore.clear()
        agenda = nil
        agendaMode = .browsing
        await composeAgenda(city: city, language: language, session: session)
    }

    /// Swap a slot's content with one of its swap options.
    @MainActor
    func swapSlot(slotId: String, with swap: AgendaSlot.SwapOption) {
        guard var current = agenda,
              let index = current.slots.firstIndex(where: { $0.id == slotId }) else { return }

        current.slots[index].venueName = swap.venueName
        current.slots[index].venueId = swap.venueId
        current.slots[index].reason = swap.detail
        current.slots[index].source = .userSwapped

        // Record the new venue
        if let venueId = swap.venueId {
            recentlyShownStore.recordShown(venueId: venueId)
        }

        self.agenda = current
        syncAgendaToWidget()
    }

    // MARK: - Slot Editing

    /// Replace a slot with custom user content.
    @MainActor
    func replaceSlotWithCustom(
        slotId: String,
        venueName: String,
        time: String,
        neighbourhood: String?,
        locked: Bool
    ) {
        guard var current = agenda,
              let index = current.slots.firstIndex(where: { $0.id == slotId }) else { return }

        current.slots[index].venueName = venueName
        current.slots[index].venueId = nil
        current.slots[index].reason = ""
        current.slots[index].time = time
        current.slots[index].source = .userCustom
        current.slots[index].isLocked = locked
        current.slots[index].customVenueName = venueName
        current.slots[index].customNeighbourhood = neighbourhood

        // Mark downstream AI-generated slots as stale
        for i in (index + 1)..<current.slots.count {
            if current.slots[i].source == .aiGenerated {
                current.slots[i].isStale = true
            }
        }

        self.agenda = current
        showReflowBanner = true
        reflowSlotId = slotId
    }

    /// Edit the time of an existing slot.
    @MainActor
    func editSlotTime(slotId: String, newTime: String) {
        guard var current = agenda,
              let index = current.slots.firstIndex(where: { $0.id == slotId }) else { return }

        current.slots[index].time = newTime

        // Mark downstream AI-generated slots as stale if time changed significantly
        for i in (index + 1)..<current.slots.count {
            if current.slots[i].source == .aiGenerated {
                current.slots[i].isStale = true
            }
        }

        self.agenda = current
    }

    /// Toggle the lock state of a slot.
    @MainActor
    func toggleSlotLock(slotId: String) {
        guard var current = agenda,
              let index = current.slots.firstIndex(where: { $0.id == slotId }) else { return }

        current.slots[index].isLocked.toggle()
        self.agenda = current
    }

    /// Remove a slot from the agenda.
    @MainActor
    func removeSlot(slotId: String) {
        guard var current = agenda else { return }
        current.slots.removeAll { $0.id == slotId }
        self.agenda = current
    }

    /// Clear stale state on all slots (user chose "Keep" on reflow banner).
    @MainActor
    func clearStaleSlots() {
        guard var current = agenda else { return }
        for i in 0..<current.slots.count {
            current.slots[i].isStale = false
        }
        self.agenda = current
        showReflowBanner = false
        reflowSlotId = nil
    }

    /// Reflow: rebuild only unlocked AI-generated slots around locked/custom constraints.
    @MainActor
    func reflowAgenda(city: City, language: AppLanguage, session: FamilySession) async {
        showReflowBanner = false
        reflowSlotId = nil

        // Mark stale slots as loading (keep them but show skeleton)
        guard var current = agenda else { return }
        for i in 0..<current.slots.count {
            current.slots[i].isStale = false
        }
        self.agenda = current

        // Full rebuild preserving locked slots
        await rebuildAgenda(city: city, language: language, session: session)
    }

    /// Whether the reflow banner should be shown.
    var showReflowBanner: Bool = false

    /// The slot ID that triggered the reflow banner.
    var reflowSlotId: String?

    // MARK: - Template Engine Fallback

    @MainActor
    private func buildTemplateFallback(session: FamilySession, language: AppLanguage, dateISO: String? = nil) {
        guard let activities = activitiesData?.activities,
              let spots = lunchData?.spots else {
            let key = dateISO ?? selectedPlanDay.isoDate
            _agendaStates[key] = .error("No data available for agenda")
            return
        }

        let events = activitiesData?.cityEvents ?? []
        let engine = TemplateEngine()
        let result = engine.buildAgenda(
            weather: weather,
            session: session,
            activities: activities,
            restaurants: spots,
            cityEvents: events,
            recentlyShown: recentlyShownStore.recentlyShownIds(),
            language: language
        )

        let key = dateISO ?? selectedPlanDay.isoDate
        _agendas[key] = result
        _agendaStates[key] = .fallback
        syncAgendaToWidget()
        restoreAgendaMode()

        // Record shown venues
        for slot in result.slots {
            if let venueId = slot.venueId {
                recentlyShownStore.recordShown(venueId: venueId)
            }
        }
    }

    // MARK: - Widget Sync

    /// Sync the nearest upcoming agenda to the shared app group UserDefaults so the widget can display it.
    private func syncAgendaToWidget() {
        // Find the nearest agenda (today first, then tomorrow, then weekend)
        let candidates: [String] = [
            Self.dateISO(Date()),
            Self.dateISO(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()),
            PlanDay.saturday.isoDate,
            PlanDay.sunday.isoDate
        ]
        let nearestAgenda = candidates.compactMap { _agendas[$0] }.first

        guard let nearest = nearestAgenda else {
            UserDefaults(suiteName: StorageKeys.widgetSuite)?.removeObject(forKey: "todayAgenda")
            WidgetCenter.shared.reloadTimelines(ofKind: "DayPlanWidget")
            return
        }
        guard let data = try? JSONEncoder().encode(nearest) else { return }
        UserDefaults(suiteName: StorageKeys.widgetSuite)?.set(data, forKey: "todayAgenda")
        WidgetCenter.shared.reloadTimelines(ofKind: "DayPlanWidget")
    }

    // MARK: - Context Banner (driven by agenda theme)

    /// Context banner text — always derived from current weather conditions.
    /// The agenda theme is decorative and may not match updated slot content,
    /// so the banner uses live weather data for accuracy.
    func contextBannerText(language: AppLanguage) -> String? {
        guard let weather else { return nil }

        if weather.isBadWeather {
            return language == .en
                ? "Rainy day — good for museums or indoor play"
                : "Regentag — perfekt für Museen oder Indoor-Spiele"
        }
        if weather.temperature < 0 {
            return language == .en
                ? "Freezing! Bundle up for a cozy indoor adventure"
                : "Eiskalt! Einpacken für ein Indoor-Abenteuer"
        }
        if weather.temperature < 10 {
            return language == .en
                ? "Cold day — indoor activities recommended"
                : "Kalter Tag — Indoor-Aktivitäten empfohlen"
        }
        if weather.temperature > 28 {
            return language == .en
                ? "Hot day! Head to a splash pad or lake"
                : "Heisser Tag! Ab ins Planschbecken oder an den See"
        }
        if weather.temperature > 18 {
            return language == .en
                ? "Beautiful day for the park or playground"
                : "Schöner Tag für Park oder Spielplatz"
        }
        return nil
    }

    // MARK: - What's On Today (Events)

    /// Events happening today: city events overlapping today + recurring activities for today's weekday + Zurich fixtures
    func todayEvents(language: AppLanguage, city: City) -> [TodayEvent] {
        let today = Date()
        var events: [TodayEvent] = []

        // 1. City events overlapping today
        for event in activitiesData?.cityEvents ?? [] where event.overlaps(with: today) {
            events.append(TodayEvent(
                id: event.id,
                emoji: event.toddlerFriendly ? "👶" : "🎪",
                name: event.localizedName(language: language),
                venue: nil,
                time: nil,
                isFree: event.free,
                price: nil
            ))
        }

        // 2. Recurring activities available today
        for activity in activitiesData?.activities ?? [] {
            guard activity.recurring != nil else { continue }
            guard activity.isAvailable(on: today) else { continue }
            guard !activity.isStayHome else { continue }

            events.append(TodayEvent(
                id: activity.id,
                emoji: Self.categoryEmoji(activity.category),
                name: activity.localizedName(language: language),
                venue: nil,
                time: activity.recurring,
                isFree: activity.isFree,
                price: activity.localizedPrice(language: language)
            ))
        }

        // 3. Zurich fixture events (filtered by today's day-of-week)
        if city == .zurich {
            let weekday = Calendar.current.component(.weekday, from: today)
            for fixture in Self.zurichFixtures {
                guard fixture.availableDays.contains(weekday) else { continue }
                // Avoid duplicates if fixture already exists as a recurring activity
                guard !events.contains(where: { $0.id == fixture.event.id }) else { continue }
                events.append(fixture.event)
            }
        }

        return events
    }

    // MARK: - News (for inline News sub-view)

    /// Currently selected news category
    var selectedCategory: String = "topStories"

    /// News items for the currently selected category
    var currentNewsItems: [NewsItem] {
        guard let categories = newsData?.categories else { return [] }
        return categories.items(for: selectedCategory)
    }

    /// Category keys that have at least one item, preserving display order
    var categoryKeys: [String] {
        guard let categories = newsData?.categories else { return [] }
        return NewsCategories.allKeys.filter { !categories.items(for: $0).isEmpty }
    }

    /// Number of items in a given category
    func newsItemCount(for key: String) -> Int {
        guard let categories = newsData?.categories else { return 0 }
        return categories.items(for: key).count
    }

    /// Top 3-4 news items for the "Local news" section
    var localNewsItems: [NewsItem] {
        guard let categories = newsData?.categories else { return [] }
        let local = categories.items(for: "local")
        let top = categories.items(for: "topStories")
        let combined = local + top
        return Array(combined.prefix(4))
    }

    /// Total news count across all categories
    var totalNewsCount: Int {
        guard let categories = newsData?.categories else { return 0 }
        return NewsCategories.allKeys.reduce(0) { $0 + categories.items(for: $1).count }
    }

    /// Total activity count for "See all N →" link
    var totalActivityCount: Int {
        activitiesData?.activities.count ?? 0
    }

    // MARK: - Zurich Fixture Events

    private struct FixtureEvent {
        let event: TodayEvent
        let availableDays: Set<Int> // 1=Sun, 2=Mon, ..., 7=Sat
    }

    private static let zurichFixtures: [FixtureEvent] = [
        FixtureEvent(
            event: TodayEvent(
                id: "zh-fixture-burkliplatz-market",
                emoji: "🧺",
                name: "Bürkliplatz Farmers Market",
                venue: "Bürkliplatz",
                time: "06:00–11:00",
                isFree: true,
                price: nil
            ),
            availableDays: [3, 6, 7] // Tue, Fri, Sat
        ),
        FixtureEvent(
            event: TodayEvent(
                id: "zh-fixture-english-storytime",
                emoji: "📖",
                name: "English Storytime",
                venue: "Pestalozzi-Bibliothek",
                time: "10:30",
                isFree: true,
                price: nil
            ),
            availableDays: [7] // Sat
        ),
        FixtureEvent(
            event: TodayEvent(
                id: "zh-fixture-stadtgaertnerei",
                emoji: "🌱",
                name: "Stadtgärtnerei",
                venue: "Sackzelg 27",
                time: "09:00–17:00",
                isFree: true,
                price: nil
            ),
            availableDays: [1, 7] // Sat, Sun
        ),
    ]

    // MARK: - Helpers

    private static func categoryEmoji(_ category: String) -> String {
        switch category.lowercased() {
        case "animals": return "🐾"
        case "playground": return "🛝"
        case "museum": return "🏛️"
        case "nature": return "🌿"
        case "water": return "💧"
        case "transport": return "🚂"
        case "creative": return "🎨"
        case "music": return "🎵"
        case "sports": return "⚽"
        case "food": return "🍽️"
        case "market": return "🧺"
        case "storytime": return "📖"
        default: return "✨"
        }
    }

    private static func dateISO(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return f.string(from: date)
    }

    // MARK: - Execution Mode

    /// Active feasibility warning after a timeline shift (one at a time, most critical).
    var activeWarning: FeasibilityWarning?

    /// Whether the timeline was visually shifted (for animation triggers).
    var timelineDidShift = false

    /// Start executing the agenda from the first slot.
    @MainActor
    func startExecuting() {
        guard let agenda else { return }
        agendaMode = .executing(currentSlotIndex: 0)

        // Schedule notifications if permission was granted
        Task {
            if await AgendaNotificationScheduler.isAuthorized() {
                AgendaNotificationScheduler.shared.schedule(for: agenda.slots)
            }
        }
    }

    /// Handle check-in: record, shift timeline if needed, check feasibility, advance.
    @MainActor
    func handleCheckIn(source: CheckInSource = .manual) {
        guard var currentAgenda = agenda,
              case .executing(let idx) = agendaMode,
              idx < currentAgenda.slots.count else { return }

        let slot = currentAgenda.slots[idx]
        let actualTime = Date()
        let delta = TimelineShifter.computeDelta(actualTime: actualTime, slot: slot)

        // 1. Record check-in time on the slot
        currentAgenda.slots[idx].checkInTime = actualTime
        currentAgenda.slots[idx].wasAutoCheckedIn = (source == .geofence)

        // 2. Record to CheckInStore
        CheckInStore.shared.record(CheckInRecord(
            venueId: slot.venueId ?? slot.venueName,
            venueName: slot.venueName,
            scheduledTime: slot.slotDate,
            actualTime: actualTime,
            delta: delta,
            source: source,
            date: Calendar.current.startOfDay(for: Date())
        ))

        // 3. Shift timeline if delta is meaningful (> 10 min)
        if abs(delta) > 600 {
            let shifted = TimelineShifter.shift(
                slots: currentAgenda.slots,
                fromIndex: idx,
                delta: delta
            )
            currentAgenda.slots = shifted

            // Trigger time shift animation
            timelineDidShift = true

            // 4. Check feasibility
            let warnings = FeasibilityChecker.check(slots: currentAgenda.slots)
            activeWarning = warnings.first

            // 5. Reschedule notifications
            Task {
                if await AgendaNotificationScheduler.isAuthorized() {
                    AgendaNotificationScheduler.shared.reschedule(for: currentAgenda.slots)
                }
            }
        }

        agenda = currentAgenda

        // 6. Advance to next slot
        let nextIdx = idx + 1
        if nextIdx < currentAgenda.slots.count {
            agendaMode = .executing(currentSlotIndex: nextIdx)
        } else {
            // All done — show completion
            agendaMode = .executing(currentSlotIndex: currentAgenda.slots.count)
            // Flush check-ins to RecentlyShownStore
            CheckInStore.shared.flushToRecentlyShown(RecentlyShownStore.shared)
        }

        // Reset shift animation flag after a delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            timelineDidShift = false
        }
    }

    /// Apply the suggested resolution from a feasibility warning.
    @MainActor
    func applyWarningResolution() {
        guard var currentAgenda = agenda,
              let warning = activeWarning else { return }

        switch warning.suggestedResolution {
        case .skipSlot(let slotId):
            // Remove the slot and advance if needed
            if let slotIndex = currentAgenda.slots.firstIndex(where: { $0.id == slotId }) {
                currentAgenda.slots.remove(at: slotIndex)
                agenda = currentAgenda
                // Adjust current slot index if we removed a slot before it
                if case .executing(let idx) = agendaMode, slotIndex < idx {
                    agendaMode = .executing(currentSlotIndex: idx - 1)
                }
            }
        case .shortenSlot:
            // Just dismiss — time was already shifted
            break
        case .none:
            break
        }

        activeWarning = nil
    }

    /// Dismiss the current feasibility warning without action.
    @MainActor
    func dismissWarning() {
        activeWarning = nil
    }

    /// Exit execution mode back to browsing.
    @MainActor
    func exitExecution() {
        // Cancel all scheduled notifications
        if let agenda {
            AgendaNotificationScheduler.shared.cancelAll(for: agenda.slots)
        }
        agendaMode = .browsing
        activeWarning = nil
    }

    /// Whether all slots are completed.
    var isAgendaComplete: Bool {
        guard let agenda, case .executing(let idx) = agendaMode else { return false }
        return idx >= agenda.slots.count
    }

    /// "Leave at" time: current slot's time minus travelMinutesToNext of the previous slot.
    /// Returns nil for the first slot.
    func leaveAtTime(for slotIndex: Int) -> String? {
        guard slotIndex > 0, let agenda, slotIndex < agenda.slots.count else { return nil }
        let prevSlot = agenda.slots[slotIndex - 1]
        guard let travelMin = prevSlot.travelMinutesToNext else { return nil }
        // Parse current slot time (HH:mm)
        let currentTime = agenda.slots[slotIndex].time
        let parts = currentTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let totalMinutes = parts[0] * 60 + parts[1] - travelMin
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    // MARK: - Mode Persistence

    private static let agendaModePrefix = "agendaMode_"

    private func persistAgendaMode() {
        let dateKey = Self.dateISO(targetDate)
        let key = Self.agendaModePrefix + dateKey
        if let data = try? JSONEncoder().encode(agendaMode) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func restoreAgendaMode() {
        let dateKey = Self.dateISO(targetDate)
        let key = Self.agendaModePrefix + dateKey
        guard let data = UserDefaults.standard.data(forKey: key),
              let mode = try? JSONDecoder().decode(AgendaMode.self, from: data) else { return }
        agendaMode = mode
    }

    /// Haversine distance in meters
    private static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

// MARK: - Today Event

/// Lightweight model for events displayed in the "What's on today" section.
struct TodayEvent: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let venue: String?
    let time: String?
    let isFree: Bool
    let price: String?
}
