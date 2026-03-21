import Foundation
import CoreLocation
import EventKit
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

    /// Multi-day daily forecast from Open-Meteo (today + next 7 days).
    var dailyForecast: [DayWeather] = []

    var isLoading = false
    var error: String?

    // MARK: - Agenda

    /// Internal storage: multiple agendas keyed by ISO date string.
    /// Internal (not private) so day pill state is accessible.
    var _agendas: [String: DayAgenda] = [:]
    var _agendaStates: [String: AgendaState] = [:]

    /// The currently selected plan day (today by default).
    var selectedPlanDay: PlanDay = .today

    /// The city being planned for (defaults to the app's selected city).
    /// Set when user taps "Plan a day here" on a sunshine/snow card.
    var planningCity: PlanningCity = .zurich

    /// Whether the calendar date picker sheet is shown.
    var showDatePicker: Bool = false

    // MARK: - Calendar Sync

    /// Calendar events pending user review (swipe screen).
    var pendingCalendarEvents: [EKEvent] = []

    /// Whether to show the CalendarSwipeView modal.
    var showCalendarSwipe = false

    /// Whether to show the sync banner (new events detected after plan is built).
    var showCalendarSyncBanner = false

    /// Number of new events for the banner text.
    var pendingBannerEventCount = 0

    /// Conflict warning message (if overlapping anchors detected after accept).
    var conflictWarning: String?

    /// Weather for a specific weekend day (fetched on demand via /weekend endpoint).
    private var _weekendWeather: WeekendResponse?

    /// Weather for a specific weekend day, from the cached /weekend response.
    func weekendDayWeather(for day: PlanDay) -> DayWeather? {
        switch day {
        case .saturday: return _weekendWeather?.saturday.weather
        case .sunday: return _weekendWeather?.sunday.weather
        default: return nil
        }
    }

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

    /// Quick-pick plan days shown in the date picker row.
    /// Always shows Today, Tomorrow, and the upcoming Sat/Sun.
    /// Deduplicates if today or tomorrow already IS Saturday/Sunday.
    var availablePlanDays: [PlanDay] {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now) // 1=Sun, 7=Sat
        var days: [PlanDay] = [.today, .tomorrow]

        // Only add weekend days if they aren't already covered by today/tomorrow
        let tomorrowWeekday = cal.component(.weekday, from: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        if weekday != 7 && tomorrowWeekday != 7 { days.append(.saturday) }
        if weekday != 1 && tomorrowWeekday != 1 { days.append(.sunday) }

        return days
    }

    // MARK: - Convenience

    var weather: Weather? { newsData?.weather }

    /// Weather for the currently selected plan day.
    /// Today: live weather from news endpoint. Future days: daily forecast from Open-Meteo.
    var weatherForSelectedDay: Weather? {
        if selectedPlanDay == .today { return weather }
        let iso = selectedPlanDay.isoDate
        guard let dayW = dailyForecast.first(where: { $0.date == iso }) else { return weather }
        return Weather(
            temperature: dayW.tempMax,
            description: dayW.description,
            weatherCode: dayW.weatherCode,
            windSpeed: 0,
            hourly: nil
        )
    }

    /// Whether the selected plan day has bad weather (for hero tinting).
    var isBadWeatherForSelectedDay: Bool {
        guard let w = weatherForSelectedDay else { return false }
        let heavyCodes: Set<Int> = [65, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
        return w.temperature < 10 && heavyCodes.contains(w.weatherCode)
    }

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

    /// After 10 PM, default to tomorrow's plan instead of today's
    var isNextDayMode: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 22
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

    /// Last-used composition parameters, stored so the notification observer can rebuild.
    private var _lastCity: City?
    private var _lastLanguage: AppLanguage?
    private var _lastSession: FamilySession?
    private var _anchorObserver: NSObjectProtocol?

    init() {
        _anchorObserver = NotificationCenter.default.addObserver(
            forName: AnchorStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self,
                  let city = self._lastCity,
                  let language = self._lastLanguage,
                  let session = self._lastSession else { return }
            Task { @MainActor in
                await self.rebuildAgenda(city: city, language: language, session: session)
            }
        }
    }

    deinit {
        if let observer = _anchorObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

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

        // Daily forecast (fire-and-forget, non-blocking)
        Task { @MainActor in
            await fetchDailyForecast(city: city)
        }

        isLoading = false

        // 3. Set selectedPlanDay based on current time
        if case .specific = selectedPlanDay {
            // Keep user's specific date selection
        } else {
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
        _lastCity = city
        _lastLanguage = language
        _lastSession = session
        await composeAgendaForDate(
            dateISO: Self.dateISO(targetDate),
            planDate: targetDate,
            city: city,
            language: language,
            session: session,
            extraRecentlyShown: [],
            anchors: AnchorStore.shared.anchors(for: targetDate)
        )
    }

    /// Compose agenda for the currently selected plan day (used when switching day pills).
    @MainActor
    func composeAgendaForSelectedDay(city: City, language: AppLanguage, session: FamilySession) async {
        // Clear stale conflict warning when switching days
        conflictWarning = nil

        let planDate = selectedPlanDay.date()
        let dateISO = selectedPlanDay.isoDate
        // Skip if already loaded or currently loading
        let state = _agendaStates[dateISO] ?? .idle
        guard state == .idle || state == .error("No data available for agenda") else { return }

        // Wait for data to finish loading before composing
        // (user may switch day pill while activities/lunch are still being fetched)
        if activitiesData == nil || lunchData == nil {
            _agendaStates[dateISO] = .loading
            // Poll briefly while loadAll is still in-flight
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                if activitiesData != nil && lunchData != nil { break }
                if !isLoading { break } // loadAll finished (even if data stayed nil)
            }
        }

        _lastCity = city
        _lastLanguage = language
        _lastSession = session

        // For weekend days, fetch per-day weather from the /weekend endpoint if not cached
        var forecastOverride: Weather? = nil
        if selectedPlanDay == .saturday || selectedPlanDay == .sunday {
            if _weekendWeather == nil {
                do {
                    _weekendWeather = try await APIClient.shared.fetchWeekend(
                        city: city, language: language
                    )
                } catch {
                    #if DEBUG
                    print("⚠️ Weekend weather fetch failed: \(error.localizedDescription)")
                    #endif
                }
            }
            forecastOverride = weekendDayWeather(for: selectedPlanDay)?.toWeather()
        } else if selectedPlanDay != .today {
            forecastOverride = weatherForSelectedDay
        }

        await composeAgendaForDate(
            dateISO: dateISO,
            planDate: planDate,
            city: city,
            language: language,
            session: session,
            extraRecentlyShown: [],
            anchors: AnchorStore.shared.anchors(for: planDate),
            weatherOverride: forecastOverride
        )
    }

    /// Compose an agenda for a specific date. Generalized for multi-day support.
    /// - Parameter planDate: The actual calendar date being planned (used for gap analysis).
    /// - Parameter anchors: Pre-fetched anchors for this date (from AnchorStore).
    /// - Parameter weatherOverride: If provided, used instead of `self.weather` for scoring/composition.
    ///   This is used for weekend days where we have per-day forecasts from the `/weekend` endpoint.
    @MainActor
    private func composeAgendaForDate(
        dateISO: String,
        planDate: Date,
        city: City,
        language: AppLanguage,
        session: FamilySession,
        extraRecentlyShown: [String],
        anchors currentAnchors: [AnchorEvent],
        weatherOverride: Weather? = nil
    ) async {

        // 1. Check cache (keyed by date + city + session + anchors hash)
        let anchorsHash = AgendaCache.hash(anchors: currentAnchors)
        if let cachedData = await agendaCache.get(date: dateISO, city: city.id, sessionHash: session.sessionHash, anchorsHash: anchorsHash),
           let cached = try? JSONDecoder().decode(DayAgenda.self, from: cachedData) {
            _agendas[dateISO] = cached
            _agendaStates[dateISO] = .loaded
            syncAgendaToWidget()
            restoreAgendaMode()
            return
        }

        _agendaStates[dateISO] = .loading

        // Resolve effective weather for this date (override for weekend, else today's)
        let effectiveWeather = weatherOverride ?? weather

        // 2. Gap analysis — determine what free time exists around anchors
        // For future dates, use midnight so no gaps are clipped by current time
        // (GapAnalysisEngine adds 15min to now, so midnight ensures 00:15 < 08:00 day start)
        let effectiveNow: Date = {
            let cal = Calendar.current
            if cal.isDateInToday(planDate) { return Date() }
            return cal.startOfDay(for: planDate)
        }()
        let allGaps = GapAnalysisEngine.analyse(anchors: currentAnchors, now: effectiveNow, date: planDate)
        let fillableGaps = allGaps.filter { $0.isFillable }

        #if DEBUG
        let tf = DateFormatter(); tf.dateFormat = "HH:mm"; tf.timeZone = TimeZone(identifier: "Europe/Zurich")
        print("🕐 Gap analysis: effectiveNow=\(tf.string(from: effectiveNow)) | \(allGaps.count) total gaps, \(fillableGaps.count) fillable")
        for gap in fillableGaps {
            print("   → \(gap.suggestedType?.rawValue ?? "nil") \(tf.string(from: gap.effectiveStart))–\(tf.string(from: gap.gapEnd)) (\(gap.effectiveMinutes)min)")
        }
        #endif

        // Build weather note/theme using effective weather for this date
        let dateWeatherNote: String = {
            guard let w = effectiveWeather else { return "Weather unavailable" }
            return "\(Int(w.temperature))° and \(w.description.lowercased())"
        }()
        let dateBadWeather: Bool = {
            guard let w = effectiveWeather else { return false }
            let heavyCodes: Set<Int> = [65, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
            return w.temperature < 10 && heavyCodes.contains(w.weatherCode)
        }()

        // 3. Anchor-only agenda — no gaps to fill, just show anchors
        if fillableGaps.isEmpty && !currentAnchors.isEmpty {
            let anchorSlots = currentAnchors
                .map { anchorToSlot($0, language: language) }
                .sorted { $0.time < $1.time }
            let agenda = DayAgenda(
                date: dateISO,
                theme: buildTheme(session: session, language: language),
                weatherNote: dateWeatherNote,
                badWeatherMode: dateBadWeather,
                slots: anchorSlots,
                homeActivities: nil
            )
            _agendas[dateISO] = agenda
            _agendaStates[dateISO] = .loaded
            syncAgendaToWidget()
            restoreAgendaMode()
            return
        }

        // 4. AI path: scored pool → AgendaComposer → merge with anchors
        if let w = effectiveWeather,
           let activities = activitiesData?.activities,
           let spots = lunchData?.spots,
           let apiKey = Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String,
           !apiKey.isEmpty,
           apiKey != "$(ANTHROPIC_API_KEY)",
           !fillableGaps.isEmpty {

            let pool = FreshnessScorer.buildScoredPool(
                activities: activities,
                restaurants: spots,
                weather: w,
                date: planDate,
                fillableGaps: fillableGaps,
                visitStore: .shared
            )

            #if DEBUG
            let gapTypes = fillableGaps.map { $0.suggestedType?.rawValue ?? "nil" }.joined(separator: ", ")
            print("📊 Compose: \(fillableGaps.count) gaps [\(gapTypes)] | pool: \(pool.activities.count) activities, \(pool.lunches.count) lunches, \(pool.dinners.count) dinners")
            #endif

            do {
                let aiSlots = try await AgendaComposer.compose(
                    gaps: fillableGaps,
                    activities: pool.activities,
                    lunches: pool.lunches,
                    dinners: pool.dinners,
                    weather: w,
                    session: session,
                    language: language,
                    apiKey: apiKey,
                    planDate: planDate
                )

                // Merge: anchor display slots + AI slots → sorted by time
                var allSlots = currentAnchors.map { anchorToSlot($0, language: language) }
                allSlots.append(contentsOf: aiSlots)
                allSlots.sort { $0.time < $1.time }

                #if DEBUG
                print("🔗 AI merge: \(currentAnchors.count) anchors + \(aiSlots.count) AI slots = \(allSlots.count) total")
                for slot in allSlots {
                    print("   → [\(slot.id)] \(slot.time) \(slot.type.rawValue) \(slot.venueName)")
                }
                #endif

                // Enrich AI slots with swap alternatives from the pool
                allSlots = enrichWithSwaps(
                    slots: allSlots,
                    activityPool: pool.activities,
                    lunchPool: pool.lunches,
                    dinnerPool: pool.dinners,
                    language: language
                )

                let result = DayAgenda(
                    date: dateISO,
                    theme: buildTheme(session: session, language: language),
                    weatherNote: dateWeatherNote,
                    badWeatherMode: dateBadWeather,
                    slots: allSlots,
                    homeActivities: nil
                )

                _agendas[dateISO] = result
                _agendaStates[dateISO] = .loaded
                ZnuniEvent.planGenerated(source: "api", city: city.id, slotCount: result.slots.count, badWeather: result.badWeatherMode)
                syncAgendaToWidget()
                restoreAgendaMode()

                // Cache the result
                if let encoded = try? JSONEncoder().encode(result) {
                    await agendaCache.store(encoded, date: dateISO, city: city.id, sessionHash: session.sessionHash, anchorsHash: anchorsHash)
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
                print("⚠️ AgendaComposer failed, falling back to template: \(error.localizedDescription)")
                #endif
            }
        }

        // 5. Template engine fallback
        // Only apply gap-aware filtering when there are actual anchors.
        // Without anchors, the template should return all slots regardless of current time.
        let hasAnchors = !currentAnchors.isEmpty
        let gapsForTemplate = hasAnchors ? (fillableGaps.isEmpty ? nil : fillableGaps) : nil
        #if DEBUG
        print("📋 Falling back to template engine (fillableGaps: \(fillableGaps.count), hasAnchors: \(hasAnchors))")
        #endif
        buildTemplateFallback(session: session, language: language, dateISO: dateISO, fillableGaps: gapsForTemplate, planDate: planDate)
    }

    /// Invalidate cache and recompose the agenda for the currently selected day.
    @MainActor
    func rebuildAgenda(city: City, language: AppLanguage, session: FamilySession) async {
        ZnuniEvent.planRebuilt()
        clearExportedEvents()
        conflictWarning = nil
        await agendaCache.invalidate()
        recentlyShownStore.clear()
        agenda = nil
        agendaMode = .browsing
        let planDate = selectedPlanDay.date()
        let dateISO = selectedPlanDay.isoDate
        _lastCity = city
        _lastLanguage = language
        _lastSession = session
        let forecastOverride: Weather? = (selectedPlanDay == .today) ? nil : weatherForSelectedDay
        await composeAgendaForDate(
            dateISO: dateISO,
            planDate: planDate,
            city: city,
            language: language,
            session: session,
            extraRecentlyShown: [],
            anchors: AnchorStore.shared.anchors(for: planDate),
            weatherOverride: forecastOverride
        )
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
        ZnuniEvent.planSlotSwapped(slotType: current.slots[index].type.rawValue)

        // Recalculate travel connectors for affected slots
        recalcTravel(in: &current.slots, at: index)

        // Record the new venue
        if let venueId = swap.venueId {
            recentlyShownStore.recordShown(venueId: venueId)
        }

        // Auto-update exported calendar event if plan was saved
        if let eventId = CalendarExportStore.shared.eventId(for: slotId) {
            let slot = current.slots[index]
            let duration = slot.durationMinutes ?? 90
            try? CalendarService.shared.updateEvent(
                id: eventId,
                title: swap.venueName,
                startDate: slot.slotDate,
                endDate: slot.slotDate.addingTimeInterval(Double(duration) * 60),
                notes: swap.detail
            )
        }

        self.agenda = current
        syncAgendaToWidget()
    }

    // MARK: - Calendar Sync Methods

    /// Check for new calendar events on the selected plan day.
    /// If plan exists → show banner. If no plan yet → set pending for swipe sheet.
    @MainActor
    func checkCalendarSync() {
        guard CalendarService.shared.hasAccess else { return }
        let planDate = selectedPlanDay.date()
        let anchors = AnchorStore.shared.anchors(for: planDate)
        let newEvents = CalendarSyncChecker.newEvents(
            for: planDate,
            existingAnchors: anchors
        )

        guard !newEvents.isEmpty else {
            showCalendarSyncBanner = false
            return
        }

        if agenda != nil {
            // Plan already built — show banner instead of auto-presenting
            pendingBannerEventCount = newEvents.count
            showCalendarSyncBanner = true
        } else {
            // No plan yet — present swipe sheet
            pendingCalendarEvents = newEvents
            showCalendarSwipe = true
        }
    }

    /// User tapped "Sync" button — request access if needed, then check.
    @MainActor
    func handleCalendarSync(toast: ToastManager) async {
        if !CalendarService.shared.hasAccess {
            let granted = await CalendarService.shared.requestAccess()
            guard granted else {
                toast.show("Calendar access needed", type: .error)
                return
            }
        }

        let planDate = selectedPlanDay.date()
        let anchors = AnchorStore.shared.anchors(for: planDate)
        let newEvents = CalendarSyncChecker.newEvents(
            for: planDate,
            existingAnchors: anchors
        )

        if newEvents.isEmpty {
            toast.show("Calendar is up to date", type: .info)
        } else {
            pendingCalendarEvents = newEvents
            showCalendarSwipe = true
            showCalendarSyncBanner = false
        }
    }

    /// Handle accepted anchors from the swipe view.
    @MainActor
    func handleCalendarSwipeComplete(
        acceptedAnchors: [AnchorEvent],
        city: City, language: AppLanguage, session: FamilySession
    ) async {
        guard !acceptedAnchors.isEmpty else { return }

        let planDate = selectedPlanDay.date()

        // Add accepted anchors to store
        for anchor in acceptedAnchors {
            AnchorStore.shared.add(anchor, for: planDate)
        }

        // Check for conflicts
        let allAnchors = AnchorStore.shared.anchors(for: planDate)
        let conflicts = CalendarSyncChecker.detectConflicts(anchors: allAnchors)
        if let first = conflicts.first {
            conflictWarning = "\(first.0.title) and \(first.1.title) overlap — check your plan"
        } else {
            conflictWarning = nil
        }

        // Invalidate cache and recompose
        await agendaCache.invalidate()
        await rebuildAgenda(city: city, language: language, session: session)
    }

    /// Export the current plan to iOS Calendar.
    @MainActor
    func exportPlanToCalendar(toast: ToastManager) async {
        guard let current = agenda else { return }

        if !CalendarService.shared.hasAccess {
            let granted = await CalendarService.shared.requestAccess()
            guard granted else {
                toast.show("Calendar access needed", type: .error)
                return
            }
        }

        // Remove previously exported events
        for (_, eventId) in CalendarExportStore.shared.all() {
            try? CalendarService.shared.deleteEvent(id: eventId)
        }
        CalendarExportStore.shared.removeAll()

        // Create one event per slot
        let store = CalendarService.shared.store
        for slot in current.slots {
            let event = EKEvent(eventStore: store)
            event.title = slot.venueName
            event.startDate = slot.slotDate
            let duration = slot.durationMinutes ?? 90
            event.endDate = slot.slotDate.addingTimeInterval(Double(duration) * 60)
            event.notes = slot.reason
            event.calendar = store.defaultCalendarForNewEvents

            if let eventId = try? CalendarService.shared.createEvent(event) {
                CalendarExportStore.shared.store(slotId: slot.id, eventId: eventId)
            }
        }

        toast.show("Plan saved to Calendar", type: .success)
    }

    /// Clear exported calendar events (called before plan rebuild).
    private func clearExportedEvents() {
        guard CalendarExportStore.shared.hasExportedPlan else { return }
        for (_, eventId) in CalendarExportStore.shared.all() {
            try? CalendarService.shared.deleteEvent(id: eventId)
        }
        CalendarExportStore.shared.removeAll()
    }

    /// Suggest another nearby restaurant for a lunch/dinner slot.
    /// Filters by same or adjacent ZurichArea, correct meal opening, and not recently shown.
    @MainActor
    func suggestAnotherNearby(slotId: String) {
        guard var current = agenda,
              let index = current.slots.firstIndex(where: { $0.id == slotId }),
              let spots = lunchData?.spots else { return }

        let slot = current.slots[index]
        let isLunch = slot.type == .lunch

        // Derive current venue's area from its LunchSpot coordinates
        let currentSpot = spots.first { $0.id == slot.venueId }
        let currentArea = currentSpot.flatMap { ZurichArea.from(lat: $0.lat, lon: $0.lon) }

        // Build set of acceptable areas (same + adjacent)
        var acceptableAreas: Set<ZurichArea> = []
        if let area = currentArea {
            acceptableAreas.insert(area)
            for adj in area.adjacentAreas { acceptableAreas.insert(adj) }
        }

        let recentIds = recentlyShownStore.recentlyShownIds()
        let currentVenueId = slot.venueId

        // All venue IDs already in the agenda (avoid duplicates)
        let agendaVenueIds = Set(current.slots.compactMap(\.venueId))

        let candidates = spots.filter { spot in
            // Not the current venue
            guard spot.id != currentVenueId else { return false }
            // Not already in agenda
            guard !agendaVenueIds.contains(spot.id) else { return false }
            // Not recently shown
            guard !recentIds.contains(spot.id) else { return false }
            // Correct meal opening
            if isLunch, spot.openForLunch == false { return false }
            if !isLunch, spot.openForDinner == false { return false }
            // Same or adjacent area (skip filter if area unknown)
            if !acceptableAreas.isEmpty {
                guard let spotArea = ZurichArea.from(lat: spot.lat, lon: spot.lon),
                      acceptableAreas.contains(spotArea) else { return false }
            }
            return true
        }

        guard let pick = candidates.randomElement() else { return }

        // Replace slot content
        current.slots[index].venueName = pick.name
        current.slots[index].venueId = pick.id
        current.slots[index].reason = pick.cuisineCategory ?? "restaurant"
        current.slots[index].source = .userSwapped

        // Recalculate travel connectors for affected slots
        recalcTravel(in: &current.slots, at: index)

        recentlyShownStore.recordShown(venueId: pick.id)
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

        let oldTime = current.slots[index].time
        current.slots[index].time = newTime

        // Mark downstream AI-generated slots as stale and show reflow banner
        var hasStaleDownstream = false
        for i in (index + 1)..<current.slots.count {
            if current.slots[i].source == .aiGenerated {
                current.slots[i].isStale = true
                hasStaleDownstream = true
            }
        }

        // Recalculate travel connectors around the edited slot
        recalcTravel(in: &current.slots, at: index)

        self.agenda = current

        // Show reflow banner if time actually changed and there are stale downstream slots
        if oldTime != newTime && hasStaleDownstream {
            showReflowBanner = true
            reflowSlotId = slotId
        }
    }

    /// Toggle the lock state of a slot.
    @MainActor
    func toggleSlotLock(slotId: String) {
        guard var current = agenda,
              let index = current.slots.firstIndex(where: { $0.id == slotId }) else { return }

        current.slots[index].isLocked.toggle()
        self.agenda = current
    }

    /// Remove a slot from the agenda and recalculate travel connectors.
    @MainActor
    func removeSlot(slotId: String) {
        guard var current = agenda,
              let index = current.slots.firstIndex(where: { $0.id == slotId }) else { return }

        current.slots.remove(at: index)

        // Recalculate travel connector for the predecessor (now points to a new next slot)
        if index > 0 && index < current.slots.count {
            let est = estimateTravelBetween(
                from: current.slots[index - 1].venueId,
                to: current.slots[index].venueId
            )
            current.slots[index - 1].travelMinutesToNext = est?.minutes
            current.slots[index - 1].travelNote = est.map { travelNoteText(for: $0) }
        } else if index > 0 {
            // Removed the last slot — predecessor has no next
            current.slots[index - 1].travelMinutesToNext = nil
            current.slots[index - 1].travelNote = nil
        }

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

        // Save locked/custom/anchor slots to preserve during rebuild
        let preservedSlots = agenda?.slots.filter {
            $0.isLocked || $0.source == .userCustom || $0.source == .userAnchor
        } ?? []

        // Clear stale state
        guard var current = agenda else { return }
        for i in 0..<current.slots.count {
            current.slots[i].isStale = false
        }
        self.agenda = current

        // Rebuild the agenda from scratch
        await agendaCache.invalidate()
        recentlyShownStore.clear()
        agenda = nil
        agendaMode = .browsing
        await composeAgenda(city: city, language: language, session: session)

        // Merge preserved slots back — replace matching slot IDs with the preserved versions
        guard var rebuilt = agenda, !preservedSlots.isEmpty else { return }
        for preserved in preservedSlots {
            if let idx = rebuilt.slots.firstIndex(where: { $0.id == preserved.id }) {
                rebuilt.slots[idx] = preserved
                // Ensure stale flag is cleared
                rebuilt.slots[idx].isStale = false
            } else {
                // Preserved slot has no matching ID (e.g. custom replaced lunch) — insert and re-sort
                rebuilt.slots.append(preserved)
            }
        }
        rebuilt.slots.sort { $0.time < $1.time }

        // Recalculate all travel connectors
        for i in 0..<rebuilt.slots.count {
            if i + 1 < rebuilt.slots.count {
                let est = estimateTravelBetween(
                    from: rebuilt.slots[i].venueId, to: rebuilt.slots[i + 1].venueId
                )
                rebuilt.slots[i].travelMinutesToNext = est?.minutes
                rebuilt.slots[i].travelNote = est.map { travelNoteText(for: $0) }
            } else {
                rebuilt.slots[i].travelMinutesToNext = nil
            }
        }

        self.agenda = rebuilt
    }

    /// Whether the reflow banner should be shown.
    var showReflowBanner: Bool = false

    /// The slot ID that triggered the reflow banner.
    var reflowSlotId: String?

    // MARK: - Template Engine Fallback

    @MainActor
    private func buildTemplateFallback(
        session: FamilySession,
        language: AppLanguage,
        dateISO: String? = nil,
        fillableGaps: [FreeGap]? = nil,
        planDate: Date = Date()
    ) {
        guard let activities = activitiesData?.activities,
              let spots = lunchData?.spots else {
            let key = dateISO ?? selectedPlanDay.isoDate
            _agendaStates[key] = .error("No data available for agenda")
            return
        }

        let events = activitiesData?.cityEvents ?? []
        let engine = TemplateEngine()
        var result = engine.buildAgenda(
            weather: weather,
            session: session,
            activities: activities,
            restaurants: spots,
            cityEvents: events,
            recentlyShown: recentlyShownStore.recentlyShownIds(),
            language: language,
            planDate: planDate
        )

        #if DEBUG
        print("📋 Template engine produced \(result.slots.count) slots:")
        for slot in result.slots {
            print("   → [\(slot.id)] \(slot.time) \(slot.type.rawValue) \(slot.venueName)")
        }
        #endif

        // Gap-aware filtering: only keep slots whose ID matches a fillable gap's suggestion type,
        // and adjust slot times to fall within their corresponding gap window.
        if let gaps = fillableGaps, !gaps.isEmpty {
            // Build a mapping from slot ID → corresponding gap
            var gapForSlotID: [String: FreeGap] = [:]
            for gap in gaps {
                switch gap.suggestedType {
                case .morningActivity:  gapForSlotID["morning"] = gap
                case .afternoonActivity: gapForSlotID["afternoon"] = gap
                case .quickActivity:    gapForSlotID["morning"] = gap
                case .lunch:            gapForSlotID["lunch"] = gap
                case .dinner:           gapForSlotID["dinner"] = gap
                case nil:               break
                }
            }

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")

            var filtered = result.slots
                .filter { gapForSlotID[$0.id] != nil }
                .map { slot -> AgendaSlot in
                    guard let gap = gapForSlotID[slot.id] else { return slot }
                    // Ensure the slot time falls within its gap window
                    let gapStartTime = timeFormatter.string(from: gap.effectiveStart)
                    let gapEndTime = timeFormatter.string(from: gap.gapEnd)
                    if slot.time < gapStartTime || slot.time >= gapEndTime {
                        // Snap to gap start + small offset
                        var adjusted = slot
                        let snappedDate = gap.effectiveStart.addingTimeInterval(15 * 60) // 15 min into the gap
                        let snappedTime = timeFormatter.string(from: snappedDate < gap.gapEnd ? snappedDate : gap.effectiveStart)
                        adjusted.time = snappedTime
                        adjusted.slotDate = AgendaSlot.resolveSlotDate(time: snappedTime, planDate: planDate)
                        return adjusted
                    }
                    return slot
                }

            // Merge anchor display slots
            let dateForAnchors = dateISO.flatMap { iso -> Date? in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.timeZone = TimeZone(identifier: "Europe/Zurich")
                return f.date(from: iso)
            } ?? Date()
            let anchors = AnchorStore.shared.anchors(for: dateForAnchors)
            if !anchors.isEmpty {
                filtered.append(contentsOf: anchors.map { anchorToSlot($0, language: language) })
            }
            filtered.sort { $0.time < $1.time }

            #if DEBUG
            print("📋 After gap filter + anchors: \(filtered.count) slots:")
            for slot in filtered {
                print("   → [\(slot.id)] \(slot.time) \(slot.type.rawValue) \(slot.venueName)")
            }
            #endif

            result = result.with(slots: filtered)
        }

        let key = dateISO ?? selectedPlanDay.isoDate
        _agendas[key] = result
        _agendaStates[key] = .fallback
        ZnuniEvent.planGenerated(source: "template_fallback", city: _lastCity?.id ?? "unknown", slotCount: result.slots.count, badWeather: result.badWeatherMode)
        syncAgendaToWidget()
        restoreAgendaMode()

        // Record shown venues
        for slot in result.slots {
            if let venueId = slot.venueId {
                recentlyShownStore.recordShown(venueId: venueId)
            }
        }
    }

    // MARK: - Agenda Composition Helpers

    /// Convert an AnchorEvent into a display-ready AgendaSlot.
    private func anchorToSlot(_ anchor: AnchorEvent, language: AppLanguage) -> AgendaSlot {
        let hour = Calendar.current.component(.hour, from: anchor.startTime)
        let slotType: AgendaSlot.SlotType = {
            switch anchor.category {
            case .food:
                return hour < 15 ? .lunch : .dinner
            default:
                return .activity
            }
        }()

        let categoryLabel = language == .de
            ? anchor.category.displayNameDE
            : anchor.category.displayName

        // Format end time for range display
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "HH:mm"
        endFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        let endTimeString = endFormatter.string(from: anchor.endTime)

        return AgendaSlot(
            id: "anchor-\(anchor.id.uuidString.prefix(8))",
            time: anchor.timeString,
            type: slotType,
            venueName: anchor.title,
            venueId: nil,
            reason: anchor.neighbourhood ?? categoryLabel,
            durationDisplay: "\(anchor.durationMinutes) min",
            tags: [categoryLabel],
            swaps: [],
            source: .userAnchor,
            isLocked: true,
            anchorEndTime: endTimeString
        )
    }

    /// Enrich AI-generated slots with swap alternatives from the scored pool.
    private func enrichWithSwaps(
        slots: [AgendaSlot],
        activityPool: [Activity],
        lunchPool: [LunchSpot],
        dinnerPool: [LunchSpot],
        language: AppLanguage
    ) -> [AgendaSlot] {
        let usedVenueIds = Set(slots.compactMap(\.venueId))
        return slots.map { slot in
            guard slot.source == .aiGenerated else { return slot }
            var mutable = slot
            switch slot.type {
            case .activity:
                let candidates = activityPool
                    .filter { !usedVenueIds.contains($0.id) && $0.id != slot.venueId }
                    .prefix(3)
                mutable = AgendaSlot(
                    id: mutable.id, time: mutable.time, type: mutable.type,
                    venueName: mutable.venueName, venueId: mutable.venueId,
                    reason: mutable.reason, durationDisplay: mutable.durationDisplay,
                    travelNote: mutable.travelNote, tags: mutable.tags,
                    swaps: candidates.map { act in
                        AgendaSlot.SwapOption(
                            id: act.id,
                            venueName: act.localizedName(language: language),
                            detail: (act.indoor ? "Indoor" : "Outdoor") +
                                    (act.isFree ? " · Free" : ""),
                            venueId: act.id
                        )
                    },
                    source: mutable.source, isLocked: mutable.isLocked
                )
            case .lunch:
                let candidates = lunchPool
                    .filter { !usedVenueIds.contains($0.id) && $0.id != slot.venueId }
                    .prefix(3)
                mutable = AgendaSlot(
                    id: mutable.id, time: mutable.time, type: mutable.type,
                    venueName: mutable.venueName, venueId: mutable.venueId,
                    reason: mutable.reason, durationDisplay: mutable.durationDisplay,
                    travelNote: mutable.travelNote, tags: mutable.tags,
                    swaps: candidates.map { spot in
                        AgendaSlot.SwapOption(
                            id: spot.id,
                            venueName: spot.name,
                            detail: "\(spot.cuisineDisplay) · \(String(repeating: "$", count: spot.priceTier))",
                            venueId: spot.id
                        )
                    },
                    source: mutable.source, isLocked: mutable.isLocked
                )
            case .dinner:
                let candidates = dinnerPool
                    .filter { !usedVenueIds.contains($0.id) && $0.id != slot.venueId }
                    .prefix(3)
                mutable = AgendaSlot(
                    id: mutable.id, time: mutable.time, type: mutable.type,
                    venueName: mutable.venueName, venueId: mutable.venueId,
                    reason: mutable.reason, durationDisplay: mutable.durationDisplay,
                    travelNote: mutable.travelNote, tags: mutable.tags,
                    swaps: candidates.map { spot in
                        AgendaSlot.SwapOption(
                            id: spot.id,
                            venueName: spot.name,
                            detail: "\(spot.cuisineDisplay) · \(String(repeating: "$", count: spot.priceTier))",
                            venueId: spot.id
                        )
                    },
                    source: mutable.source, isLocked: mutable.isLocked
                )
            case .homeActivity:
                break
            }
            return mutable
        }
    }

    /// Look up coordinates for a venue by ID from activities or restaurant data.
    private func venueCoordinates(for venueId: String?) -> (lat: Double, lon: Double)? {
        guard let id = venueId else { return nil }
        if let act = activitiesData?.activities.first(where: { $0.id == id }),
           let lat = act.lat, let lon = act.lon {
            return (lat, lon)
        }
        if let spot = lunchData?.spots.first(where: { $0.id == id }) {
            return (spot.lat, spot.lon)
        }
        return nil
    }

    /// Estimate travel time between two venues.
    /// Short distances (< 2 km) use walking pace; longer distances estimate public transit.
    private func estimateTravelBetween(from fromId: String?, to toId: String?) -> TravelEstimate? {
        guard let a = venueCoordinates(for: fromId),
              let b = venueCoordinates(for: toId) else { return nil }
        let locA = CLLocation(latitude: a.lat, longitude: a.lon)
        let locB = CLLocation(latitude: b.lat, longitude: b.lon)
        return TravelEstimate.estimate(from: locA, to: locB)
    }

    /// Recalculate travelMinutesToNext for a slot and its predecessor after a swap.
    private func recalcTravel(in slots: inout [AgendaSlot], at index: Int) {
        // Update this slot's travel to next
        if index + 1 < slots.count {
            let est = estimateTravelBetween(from: slots[index].venueId, to: slots[index + 1].venueId)
            slots[index].travelMinutesToNext = est?.minutes
            slots[index].travelNote = est.map { travelNoteText(for: $0) }
        }
        // Update previous slot's travel to this slot
        if index > 0 {
            let est = estimateTravelBetween(from: slots[index - 1].venueId, to: slots[index].venueId)
            slots[index - 1].travelMinutesToNext = est?.minutes
            slots[index - 1].travelNote = est.map { travelNoteText(for: $0) }
        }
    }

    /// Format a travel note string from a TravelEstimate.
    private func travelNoteText(for estimate: TravelEstimate) -> String {
        switch estimate.mode {
        case .walk:
            return "\(estimate.minutes) min walk"
        case .transit:
            return "~\(estimate.minutes) min by transit"
        }
    }

    /// Human-readable weather note for the agenda theme.
    private func weatherNoteString() -> String {
        guard let w = weather else { return "Weather unavailable" }
        return "\(Int(w.temperature))° and \(w.description.lowercased())"
    }

    /// Build a personalised theme string for the agenda.
    private func buildTheme(session: FamilySession, language: AppLanguage) -> String {
        let childNames = session.children.map(\.name).joined(separator: " & ")
        let f = DateFormatter()
        f.locale = language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        f.dateFormat = "EEEE"
        let dayName = f.string(from: targetDate)

        if let w = weather, w.temperature >= 18 {
            return language == .de
                ? "Sonniger \(dayName) mit \(childNames)"
                : "Sunny \(dayName) with \(childNames)"
        }
        return language == .de
            ? "\(dayName)-Plan mit \(childNames)"
            : "\(dayName) plan with \(childNames)"
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

    // MARK: - Context Banner (gap-aware)

    /// Current fillable gaps based on anchors and time of day.
    /// Computed on demand for the context banner and header display.
    /// Uses selectedPlanDay (not targetDate) so it matches what the user is viewing.
    var currentFillableGaps: [FreeGap] {
        let planDate = selectedPlanDay.date()
        let anchors = AnchorStore.shared.anchors(for: planDate)
        let now = Calendar.current.isDateInToday(planDate) ? Date() : Calendar.current.startOfDay(for: planDate)
        return GapAnalysisEngine.analyse(anchors: anchors, now: now, date: planDate)
            .filter { $0.isFillable }
    }

    /// True when anchors exist but zero fillable gaps remain.
    /// Triggers AnchorOnlyView — no API call, no AI suggestions.
    var isAnchorOnlyState: Bool {
        let anchors = AnchorStore.shared.anchors(for: selectedPlanDay.date())
        guard !anchors.isEmpty else { return false }
        return currentFillableGaps.isEmpty
    }

    /// True when zero anchors AND zero fillable gaps (late evening, all elapsed).
    /// Triggers DayCompleteView.
    var isDayCompleteState: Bool {
        let anchors = AnchorStore.shared.anchors(for: selectedPlanDay.date())
        guard anchors.isEmpty else { return false }
        return currentFillableGaps.isEmpty
    }

    /// Gap-aware context banner text.
    /// Priority: gap state → weather → nil.
    func contextBannerText(language: AppLanguage) -> String? {
        let gaps = currentFillableGaps
        let anchors = AnchorStore.shared.anchors(for: selectedPlanDay.date())

        // All gaps elapsed — evening mode
        if gaps.isEmpty && !anchors.isEmpty {
            return language == .en
                ? "That's your day — enjoy your evening."
                : "Das war's — geniess den Abend."
        }

        // Anchors fill the whole day — no gaps
        if gaps.isEmpty && anchors.isEmpty {
            // Late in the day, no anchors
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 20 {
                return language == .en
                    ? "That's your day — enjoy your evening."
                    : "Das war's — geniess den Abend."
            }
        }

        // Day is full (anchors but no fillable gaps)
        if gaps.isEmpty && !anchors.isEmpty {
            return language == .en
                ? "Your day is pretty full — enjoy what you have."
                : "Dein Tag ist ziemlich voll — geniess was du hast."
        }

        // Bad weather — indoor only
        if isBadWeatherDay {
            return language == .en
                ? "Cold and wet today — indoor suggestions only."
                : "Kalt und nass heute — nur Indoor-Vorschläge."
        }

        // Single gap remaining
        if gaps.count == 1, let type = gaps[0].suggestedType {
            let typeName: String
            switch type {
            case .morningActivity:
                typeName = language == .en ? "morning activity" : "Morgenaktivität"
            case .lunch:
                typeName = language == .en ? "lunch" : "Mittagessen"
            case .afternoonActivity:
                typeName = language == .en ? "afternoon activity" : "Nachmittagsaktivität"
            case .dinner:
                typeName = language == .en ? "dinner" : "Abendessen"
            case .quickActivity:
                typeName = language == .en ? "quick activity" : "kurze Aktivität"
            }
            return language == .en
                ? "Most of today is covered — one \(typeName) suggestion left."
                : "Der Tag ist fast geplant — noch ein Vorschlag für \(typeName)."
        }

        // Weather-based fallback — use weather for the selected day, not just today
        guard let weather = weatherForSelectedDay else { return nil }

        if weather.temperature < 0 {
            return language == .en
                ? "Freezing! Bundle up for a cozy indoor adventure."
                : "Eiskalt! Einpacken für ein Indoor-Abenteuer."
        }
        if weather.temperature < 10 {
            return language == .en
                ? "Cold day — indoor activities recommended."
                : "Kalter Tag — Indoor-Aktivitäten empfohlen."
        }
        if weather.temperature > 28 {
            return language == .en
                ? "Hot day! Head to a splash pad or lake."
                : "Heisser Tag! Ab ins Planschbecken oder an den See."
        }
        if weather.temperature > 18 {
            return language == .en
                ? "Beautiful day for the park or playground."
                : "Schöner Tag für Park oder Spielplatz."
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

    /// Handle check-in (Done ✓): record departure, shift timeline if late, advance.
    ///
    /// Delta is computed as `actualDepartureTime − scheduledEndDate`:
    /// - positive → left late (ran over), shift downstream slots forward
    /// - negative → left early, NO shift (show early-finish banner if next venue closed)
    /// - |delta| ≤ 10 min → ignore, no shift
    @MainActor
    func handleCheckIn(source: CheckInSource = .manual) {
        guard var currentAgenda = agenda,
              case .executing(let idx) = agendaMode,
              idx < currentAgenda.slots.count else { return }

        let slot = currentAgenda.slots[idx]
        let actualDepartureTime = Date()
        let delta = TimelineShifter.computeDelta(actualDepartureTime: actualDepartureTime, slot: slot)

        // 1. Mark departure on the slot
        currentAgenda.slots[idx].checkOutTime = actualDepartureTime
        currentAgenda.slots[idx].wasAutoCheckedIn = (source == .geofence)

        // 2. Record to CheckInStore
        CheckInStore.shared.record(CheckInRecord(
            venueId: slot.venueId ?? slot.venueName,
            venueName: slot.venueName,
            scheduledTime: slot.slotDate,
            scheduledEndTime: slot.scheduledEndDate,
            actualDepartureTime: actualDepartureTime,
            delta: delta,
            source: source,
            date: Calendar.current.startOfDay(for: Date())
        ))

        // 3. Record to VenueVisitStore for freshness scoring
        let venueType: VenueType = (slot.type == .lunch || slot.type == .dinner) ? .restaurant : .activity
        VenueVisitStore.shared.recordVisit(
            venueId: slot.venueId ?? slot.venueName,
            venueName: slot.venueName,
            venueType: venueType,
            source: .executionCheckIn
        )

        // 4. Timeline shift logic
        // Only shift downstream when LATE by more than 10 min.
        // Early finish (delta < 0) never shifts — we don't pull slots earlier.
        if delta > 600 {
            let shifted = TimelineShifter.shift(
                slots: currentAgenda.slots,
                fromIndex: idx,
                delta: delta
            )
            currentAgenda.slots = shifted

            // Trigger time shift animation
            timelineDidShift = true

            // 5. Check feasibility after shift
            let warnings = FeasibilityChecker.check(slots: currentAgenda.slots)
            activeWarning = warnings.first

            // 6. Reschedule notifications
            Task {
                if await AgendaNotificationScheduler.isAuthorized() {
                    AgendaNotificationScheduler.shared.reschedule(for: currentAgenda.slots)
                }
            }
        } else if delta < -600 {
            // Early finish — check if next venue is still open at the earlier arrival time
            let nextIdx = idx + 1
            if nextIdx < currentAgenda.slots.count {
                let nextSlot = currentAgenda.slots[nextIdx]
                let earlyArrival = actualDepartureTime.addingTimeInterval(
                    TimeInterval((nextSlot.travelMinutesToNext ?? slot.travelMinutesToNext ?? 10) * 60)
                )
                // Show advisory banner if next venue may not be open yet
                let nextHour = Calendar.current.component(.hour, from: earlyArrival)
                let nextMinute = Calendar.current.component(.minute, from: earlyArrival)
                let nextSlotHour = Calendar.current.component(.hour, from: nextSlot.slotDate)
                if nextHour < nextSlotHour || (nextHour == nextSlotHour && nextMinute < Calendar.current.component(.minute, from: nextSlot.slotDate)) {
                    // Arrived well before next slot's scheduled time — show early finish info
                    activeWarning = FeasibilityWarning(
                        slotId: nextSlot.id,
                        type: .venueClosedAtShiftedTime,
                        message: "You're early! \(nextSlot.venueName) is scheduled for \(nextSlot.time). Head there or enjoy some free time.",
                        suggestedResolution: nil
                    )
                }
            }
        }

        agenda = currentAgenda

        // 7. Advance to next slot
        let nextIdx = idx + 1
        if nextIdx < currentAgenda.slots.count {
            agendaMode = .executing(currentSlotIndex: nextIdx)
        } else {
            // All done — show completion
            agendaMode = .executing(currentSlotIndex: currentAgenda.slots.count)
            // Flush check-ins to RecentlyShownStore
            CheckInStore.shared.flushToRecentlyShown(RecentlyShownStore.shared)
            // Record planCompletion visits for any AI slots that were NOT manually checked in
            recordPlanCompletionVisits(slots: currentAgenda.slots)
        }

        // Reset shift animation flag after a delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            timelineDidShift = false
        }
    }

    /// Record planCompletion visits for AI-generated slots that were not manually checked in.
    /// Called when the user reaches the end of execution mode.
    /// These visits have 50% weight in freshness scoring per the spec.
    private func recordPlanCompletionVisits(slots: [AgendaSlot]) {
        for slot in slots {
            // Only record for AI-generated/swapped slots that have a venueId and were NOT already checked in
            guard slot.source == .aiGenerated || slot.source == .userSwapped,
                  let venueId = slot.venueId,
                  slot.checkOutTime == nil else { continue }

            let venueType: VenueType = (slot.type == .lunch || slot.type == .dinner) ? .restaurant : .activity
            VenueVisitStore.shared.recordVisit(
                venueId: venueId,
                venueName: slot.venueName,
                venueType: venueType,
                source: .planCompletion
            )
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

    // MARK: - Daily Forecast

    /// Fetch an 8-day daily forecast from Open-Meteo for the selected city.
    /// Populates `dailyForecast` with `DayWeather` entries covering the date picker range.
    @MainActor
    private func fetchDailyForecast(city: City) async {
        let coord = city.coordinate
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(coord.latitude)&longitude=\(coord.longitude)"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&forecast_days=8&timezone=Europe/Zurich"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let daily = json?["daily"] as? [String: Any],
                  let dates = daily["time"] as? [String],
                  let codes = daily["weather_code"] as? [Int],
                  let maxTemps = daily["temperature_2m_max"] as? [Double],
                  let minTemps = daily["temperature_2m_min"] as? [Double]
            else { return }

            let descriptions: [String: String] = [
                "0": "Clear sky", "1": "Mainly clear", "2": "Partly cloudy", "3": "Overcast",
                "45": "Foggy", "48": "Foggy",
                "51": "Light drizzle", "53": "Drizzle", "55": "Heavy drizzle",
                "61": "Light rain", "63": "Rain", "65": "Heavy rain",
                "71": "Light snow", "73": "Snow", "75": "Heavy snow",
                "80": "Rain showers", "81": "Rain showers", "82": "Heavy showers",
                "85": "Snow showers", "86": "Heavy snow showers",
                "95": "Thunderstorm", "96": "Thunderstorm with hail", "99": "Thunderstorm with hail"
            ]

            var forecast: [DayWeather] = []
            for i in 0..<dates.count {
                let desc = descriptions["\(codes[i])"] ?? "Unknown"
                forecast.append(DayWeather(
                    date: dates[i],
                    weatherCode: codes[i],
                    tempMax: maxTemps[i],
                    tempMin: minTemps[i],
                    description: desc
                ))
            }
            self.dailyForecast = forecast
        } catch {
            // Silently fail — weather display will fall back to today's weather
        }
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
