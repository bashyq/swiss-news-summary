import SwiftUI
import EventKit
import CoreLocation
import MapKit
import os.log

private let planLog = Logger(subsystem: "Bashar.Znuni", category: "PlanViewModel")

// MARK: - Plan State

/// State machine for the Plan tab's composition lifecycle.
enum PlanState {
    case empty
    case calendarPreview([CalendarSlot])
    case composing(locked: [AgendaSlot])
    case dealt(DayAgenda)
    case saved(DayAgenda)
    case error(String)
}

// MARK: - PlanViewModel

/// Core orchestrator for the Plan tab — handles agenda composition
/// with a clean state machine built around the card-dealing interaction model.
///
/// States: empty → calendarPreview → composing → dealt ⇄ saved
/// Actions: deal / redeal / lock / unlock / remove / replaceWithCustom / saveToCalendar
@Observable
final class PlanViewModel {

    // MARK: - State

    var planState: PlanState = .empty
    var selectedDate: Date
    var planningCity: PlanningCity

    /// Calendar events the user has unlocked in calendarPreview (don't plan around these).
    var excludedCalendarIds: Set<String> = []

    /// Family session — loaded from UserDefaults.
    var session: FamilySession

    // MARK: - Plan Store

    let store: PlanStoreProvider = LocalPlanStore.shared

    // MARK: - Cached Data Pools

    /// Raw data fetched from API — cached across date switches.
    private(set) var activitiesData: ActivitiesResponse?
    private(set) var lunchData: LunchResponse?
    private(set) var weather: Weather?

    /// 7-day forecast keyed by ISO date string (e.g. "2026-03-23").
    /// Fetched once from Open-Meteo, used to show per-day weather in the hero banner.
    private(set) var dailyForecasts: [String: DailyForecast] = [:]

    /// Whether data pools are currently loading.
    var isLoadingData = false

    /// Last successfully dealt agenda for the current date — used as fallback in error state.
    var lastDealtAgenda: DayAgenda? {
        store.loadPlan(city: planningCity.id, date: isoString(for: selectedDate))
    }

    // MARK: - Date Strip

    /// 14 days starting from today for the date strip.
    var dates: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    // MARK: - Dependencies

    private let calendarBridge = CalendarBridge()
    private let anchorStore = AnchorStore.shared
    private let recentlyShownStore = RecentlyShownStore.shared
    private let visitStore = VenueVisitStore.shared
    private let templateEngine = TemplateEngine()

    // MARK: - Init

    init(city: PlanningCity = .zurich) {
        self.planningCity = city
        self.session = FamilySession.load()

        // 22:00 auto-default: if current hour >= 22, default to tomorrow
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 {
            self.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        } else {
            self.selectedDate = Date()
        }
    }

    // MARK: - Date Selection

    /// Select a date and load cached plan or calendar events.
    @MainActor
    func selectDate(_ date: Date, previousDate: Date? = nil) async {
        // 0. Save current agenda to store before switching (write-through — may be no-op if already saved)
        let oldDate = previousDate ?? selectedDate
        if !Calendar.current.isDate(oldDate, inSameDayAs: date), let current = currentAgenda {
            store.savePlan(current, city: planningCity.id, date: isoString(for: oldDate))
        }

        selectedDate = date
        excludedCalendarIds = []
        let dateISO = isoString(for: date)

        // 1. Check store for existing plan
        if let cached = store.loadPlan(city: planningCity.id, date: dateISO) {
            let allLocked = cached.slots.allSatisfy { $0.isLocked }
            planState = allLocked ? .saved(cached) : .dealt(cached)
            return
        }

        // 2. Check calendar for events
        let calendarSlots = calendarBridge.fetchEvents(for: date)
        if !calendarSlots.isEmpty {
            planState = .calendarPreview(calendarSlots)
            return
        }

        // 3. Nothing found
        planState = .empty
    }

    // MARK: - Deal (Core Composition)

    /// Compose an initial plan for the selected date.
    /// Accepts optional locked slots (from calendar preview or previous deal).
    @MainActor
    func deal(lockedSlots: [AgendaSlot] = []) async {
        planState = .composing(locked: lockedSlots)

        let planDate = selectedDate
        let dateISO = isoString(for: planDate)
        let city = planningCity.city
        let language = currentLanguage

        // 1. Ensure data pools are loaded
        await loadDataPoolsIfNeeded(city: city, language: language)

        guard let activities = activitiesData?.activities,
              let spots = lunchData?.spots else {
            // Try store fallback
            if let cached = store.loadPlan(city: city.id, date: dateISO) {
                planState = .dealt(cached)
            } else {
                planState = .error("No data available — check your connection")
            }
            return
        }

        // 2. Build anchors from locked slots + AnchorStore
        var anchors = anchorStore.anchors(for: planDate)

        // Convert locked calendar/custom slots to anchors
        for slot in lockedSlots {
            let anchor = slotToAnchor(slot, date: planDate)
            if !anchors.contains(where: { $0.id == anchor.id }) {
                anchors.append(anchor)
            }
        }

        // 3. Gap analysis
        let effectiveNow = effectiveNowForDate(planDate)
        let allGaps = GapAnalysisEngine.analyse(anchors: anchors, now: effectiveNow, date: planDate)
        let fillableGaps = allGaps.filter { $0.isFillable }

        // Build weather note
        let effectiveWeather = weather
        let weatherNote = weatherNoteString(effectiveWeather)
        let badWeather = isBadWeather(effectiveWeather)

        // 4. Anchor-only agenda — no gaps to fill
        if fillableGaps.isEmpty {
            let anchorSlots = anchors.map { anchorToSlot($0) }
                .sorted { $0.time < $1.time }
            var allSlots = mergeLockedAndAnchorSlots(locked: lockedSlots, anchorSlots: anchorSlots)
            populateTravelEstimates(in: &allSlots)

            let agenda = DayAgenda(
                date: dateISO,
                theme: buildTheme(),
                weatherNote: weatherNote,
                badWeatherMode: badWeather,
                slots: allSlots,
                homeActivities: nil
            )
            planState = .dealt(agenda)
            store.savePlan(agenda, city: planningCity.id, date: dateISO)
            return
        }

        // 5. AI path: scored pool -> AgendaComposer -> merge
        if let w = effectiveWeather,
           let apiKey = Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String,
           !apiKey.isEmpty,
           apiKey != "$(ANTHROPIC_API_KEY)" {

            let pool = FreshnessScorer.buildScoredPool(
                activities: activities,
                restaurants: spots,
                weather: w,
                date: planDate,
                fillableGaps: fillableGaps,
                visitStore: visitStore
            )

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

                // Merge: locked slots + anchor display slots + AI slots
                var allSlots = lockedSlots
                let anchorSlots = anchors.map { anchorToSlot($0) }
                for aSlot in anchorSlots {
                    if !allSlots.contains(where: { $0.id == aSlot.id || $0.venueName == aSlot.venueName }) {
                        allSlots.append(aSlot)
                    }
                }
                allSlots.append(contentsOf: aiSlots)
                // Deduplicate by venue name
                var seenAI = Set<String>()
                allSlots = allSlots.filter { slot in
                    let key = slot.venueName
                    if seenAI.contains(key) { return false }
                    seenAI.insert(key)
                    return true
                }
                allSlots.sort { $0.time < $1.time }
                populateTravelEstimates(in: &allSlots)

                let agenda = DayAgenda(
                    date: dateISO,
                    theme: buildTheme(),
                    weatherNote: weatherNote,
                    badWeatherMode: badWeather,
                    slots: allSlots,
                    homeActivities: nil
                )

                planState = .dealt(agenda)
                ZnuniEvent.planGenerated(
                    source: "api", city: city.id,
                    slotCount: agenda.slots.count, badWeather: badWeather
                )
                store.savePlan(agenda, city: planningCity.id, date: dateISO)
                recordShownVenues(agenda)
                return
            } catch {
                #if DEBUG
                print("⚠️ AgendaComposer failed, falling back to template: \(error.localizedDescription)")
                #endif
            }
        }

        // 6. Template engine fallback
        // Exclude locked venues from the pool so template doesn't re-suggest them
        let lockedVenueNames = Set(lockedSlots.map { $0.venueName })
        let filteredActivities = activities.filter { !lockedVenueNames.contains($0.name) }
        let filteredSpots = spots.filter { !lockedVenueNames.contains($0.name) }

        let events = activitiesData?.cityEvents ?? []
        var result = templateEngine.buildAgenda(
            weather: effectiveWeather,
            session: session,
            activities: filteredActivities,
            restaurants: filteredSpots,
            cityEvents: events,
            recentlyShown: recentlyShownStore.recentlyShownIds(),
            language: language,
            visitStore: visitStore,
            planDate: planDate
        )

        // Gap-aware filtering: only keep slots matching fillable gaps
        var filteredSlots = filterSlotsToGaps(result.slots, gaps: fillableGaps, planDate: planDate)

        // Merge locked slots — they take priority over template-generated ones (have full data like venueId/photos)
        for slot in lockedSlots {
            if let existingIdx = filteredSlots.firstIndex(where: { $0.id == slot.id || $0.venueName == slot.venueName }) {
                // Replace template slot with locked slot (locked has venueId, photo data, etc.)
                filteredSlots[existingIdx] = slot
            } else {
                filteredSlots.append(slot)
            }
        }
        // Only add anchor slots that aren't already represented by a locked slot or template slot
        let anchorSlots = anchors.map { anchorToSlot($0) }
        for aSlot in anchorSlots {
            if !filteredSlots.contains(where: { $0.id == aSlot.id || $0.venueName == aSlot.venueName }) {
                filteredSlots.append(aSlot)
            }
        }
        // Deduplicate by venue name (template engine can produce duplicates)
        var seenVenues = Set<String>()
        filteredSlots = filteredSlots.filter { slot in
            let key = slot.venueName
            if seenVenues.contains(key) { return false }
            seenVenues.insert(key)
            return true
        }

        filteredSlots.sort { $0.time < $1.time }
        populateTravelEstimates(in: &filteredSlots)

        result = result.with(slots: filteredSlots)
        planState = .dealt(result)
        ZnuniEvent.planGenerated(
            source: "template", city: city.id,
            slotCount: result.slots.count, badWeather: result.badWeatherMode
        )
        store.savePlan(result, city: planningCity.id, date: dateISO)
        recordShownVenues(result)
    }

    // MARK: - Redeal

    /// Recompose unlocked slots while preserving locked ones.
    @MainActor
    func redeal() async {
        guard let current = currentAgenda else { return }
        let locked = current.slots.filter { $0.isLocked }
        ZnuniEvent.planRebuilt()
        store.deletePlan(city: planningCity.id, date: isoString(for: selectedDate))
        recentlyShownStore.clear()
        await deal(lockedSlots: locked)
    }

    // MARK: - City Change

    /// Switch planning city: invalidate data pools and reset plan state.
    /// Planning city is independent from the global app city (News tab).
    func changeCity(to newCity: PlanningCity) {
        // Save current plan before switching
        if let current = currentAgenda {
            store.savePlan(current, city: planningCity.id, date: isoString(for: selectedDate))
        }
        planningCity = newCity
        invalidateDataPools()
        // Check if we have a cached plan for this city+date
        let dateISO = isoString(for: selectedDate)
        if let cached = store.loadPlan(city: newCity.id, date: dateISO) {
            let allLocked = cached.slots.allSatisfy { $0.isLocked }
            planState = allLocked ? .saved(cached) : .dealt(cached)
        } else {
            planState = .empty
        }
    }

    /// Clear cached data pools so the next deal() re-fetches for the current city.
    private func invalidateDataPools() {
        activitiesData = nil
        lunchData = nil
        weather = nil
        dailyForecasts = [:]
    }

    // MARK: - Slot Actions

    /// Lock a slot so it survives redeals.
    func lock(slotId: String) {
        guard var agenda = currentAgenda,
              let idx = agenda.slots.firstIndex(where: { $0.id == slotId }) else { return }
        agenda.slots[idx].isLocked = true
        updateAgenda(agenda)
    }

    /// Unlock a slot for replacement on redeal.
    func unlock(slotId: String) {
        // In calendar preview, mark event as excluded (don't plan around it)
        if case .calendarPreview = planState {
            excludedCalendarIds.insert(slotId)
            return
        }
        guard var agenda = currentAgenda,
              let idx = agenda.slots.firstIndex(where: { $0.id == slotId }) else { return }
        agenda.slots[idx].isLocked = false
        updateAgenda(agenda)
    }

    /// Re-lock a previously excluded calendar event in preview.
    func lockCalendarEvent(slotId: String) {
        excludedCalendarIds.remove(slotId)
    }

    /// Remove a slot from the current agenda. If calendar source, discard it.
    func remove(slotId: String) {
        // Handle calendar preview state
        if case .calendarPreview(var events) = planState {
            store.discard(eventId: slotId)
            events.removeAll { $0.id == slotId }
            planState = events.isEmpty ? .empty : .calendarPreview(events)
            return
        }
        guard var agenda = currentAgenda,
              let idx = agenda.slots.firstIndex(where: { $0.id == slotId }) else { return }
        let slot = agenda.slots[idx]
        if slot.source == .calendar {
            store.discard(eventId: slotId)
        }
        agenda.slots.remove(at: idx)
        populateTravelEstimates(in: &agenda.slots)
        updateAgenda(agenda)
    }

    /// Replace a slot with a user-custom entry.
    /// If an address is provided, geocodes it to get coordinates for travel estimates.
    @MainActor
    func replaceWithCustom(slotId: String, name: String, start: Date, end: Date, address: String?) async {
        guard var agenda = currentAgenda,
              let idx = agenda.slots.firstIndex(where: { $0.id == slotId }) else { return }

        let durationMin = Int(end.timeIntervalSince(start) / 60)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")

        var lat: Double? = nil
        var lon: Double? = nil

        // Geocode address if provided
        if let address, !address.isEmpty {
            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.geocodeAddressString(address + ", Switzerland"),
               let location = placemarks.first?.location {
                lat = location.coordinate.latitude
                lon = location.coordinate.longitude
            }
        }

        agenda.slots[idx] = AgendaSlot(
            id: slotId,
            time: timeFormatter.string(from: start),
            type: agenda.slots[idx].type,
            venueName: name,
            venueId: nil,
            reason: address ?? "",
            tags: [],
            lat: lat,
            lon: lon,
            durationMinutes: durationMin,
            source: .userCustom,
            isLocked: true,
            customVenueName: name,
            slotDate: start
        )

        agenda.slots.sort { $0.time < $1.time }
        populateTravelEstimates(in: &agenda.slots)
        updateAgenda(agenda)
        ZnuniEvent.planSlotEdited(action: "custom")
    }

    /// Clear the entire plan for the current date and return to empty state.
    func clearPlan() {
        store.deletePlan(city: planningCity.id, date: isoString(for: selectedDate))
        planState = .empty
    }

    // MARK: - Weather Pre-fetch

    /// Load weather data so it shows in the hero before the user taps "Plan my day".
    @MainActor
    func loadWeatherIfNeeded() async {
        guard weather == nil else { return }
        let city = planningCity.city
        let language = currentLanguage
        do {
            let news = try await APIClient.shared.fetchNews(city: city, language: language)
            self.weather = news.weather
        } catch {}
    }

    /// Load 7-day daily forecast from Open-Meteo for the planning city.
    /// Called once on first appear; cached across date switches.
    @MainActor
    func loadDailyForecastsIfNeeded() async {
        guard dailyForecasts.isEmpty else { return }
        let coord = planningCity.city.coordinate
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let endDate = cal.date(byAdding: .day, value: 13, to: today) else { return }

        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        isoFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        let startStr = isoFormatter.string(from: today)
        let endStr = isoFormatter.string(from: endDate)

        let urlString = "https://api.open-meteo.com/v1/forecast?"
            + "latitude=\(coord.latitude)&longitude=\(coord.longitude)"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&timezone=Europe/Zurich"
            + "&start_date=\(startStr)&end_date=\(endStr)"

        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let daily = json["daily"] as? [String: Any],
                  let dates = daily["time"] as? [String],
                  let codes = daily["weather_code"] as? [Int],
                  let highs = daily["temperature_2m_max"] as? [Double],
                  let lows = daily["temperature_2m_min"] as? [Double] else { return }

            var forecasts: [String: DailyForecast] = [:]
            for i in 0..<dates.count {
                forecasts[dates[i]] = DailyForecast(
                    date: dates[i],
                    weatherCode: codes[i],
                    highTemp: highs[i],
                    lowTemp: lows[i],
                    description: APIClient.weatherDescription(for: codes[i])
                )
            }
            self.dailyForecasts = forecasts
        } catch {
            planLog.warning("Failed to load daily forecasts: \(error.localizedDescription)")
        }
    }

    /// Daily forecast for the currently selected date, if available.
    var forecastForSelectedDate: DailyForecast? {
        let dateKey = isoString(for: selectedDate)
        return dailyForecasts[dateKey]
    }

    /// Whether the selected date is today (use live weather) or a future date (use forecast).
    var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    // MARK: - Save to Calendar

    /// Lock all slots and export to iOS Calendar.
    @MainActor
    func saveToCalendar() async throws {
        guard var agenda = currentAgenda else { return }

        // Request access if needed
        if !calendarBridge.hasAccess {
            let granted = await calendarBridge.requestAccess()
            guard granted else {
                planState = .error("Calendar access needed to save plan")
                return
            }
        }

        // Lock all slots
        for i in agenda.slots.indices {
            agenda.slots[i].isLocked = true
        }

        // Export
        let _ = try calendarBridge.exportPlan(agenda.slots, city: planningCity.name)

        // Cache and transition to saved
        let dateISO = isoString(for: selectedDate)
        let anchors = anchorStore.anchors(for: selectedDate)
        store.savePlan(agenda, city: planningCity.id, date: dateISO)
        planState = .saved(agenda)
    }

    // MARK: - Helpers (Current Agenda)

    /// The current DayAgenda regardless of state.
    var currentAgenda: DayAgenda? {
        switch planState {
        case .dealt(let a), .saved(let a): return a
        default: return nil
        }
    }

    /// Whether we're in the composing state.
    var isComposing: Bool {
        if case .composing = planState { return true }
        return false
    }

    /// Fetch real travel times from MapKit and update slots asynchronously.
    @MainActor
    func fetchMapKitTravelTimes() async {
        guard var agenda = currentAgenda else { return }
        var updated = false
        for i in 0..<agenda.slots.count {
            guard i + 1 < agenda.slots.count,
                  let fromLat = agenda.slots[i].lat, let fromLon = agenda.slots[i].lon,
                  let toLat = agenda.slots[i + 1].lat, let toLon = agenda.slots[i + 1].lon else { continue }

            let source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: fromLat, longitude: fromLon)))
            let dest = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: toLat, longitude: toLon)))

            let request = MKDirections.Request()
            request.source = source
            request.destination = dest

            let distance = TravelEstimate.haversine(lat1: fromLat, lon1: fromLon, lat2: toLat, lon2: toLon)
            request.transportType = distance < 1500 ? .walking : .transit

            let directions = MKDirections(request: request)
            if let response = try? await directions.calculate() {
                let minutes = Int(response.routes.first?.expectedTravelTime ?? 0) / 60
                if minutes > 0 {
                    let mode: TravelMode = request.transportType == .walking ? .walking : .transit
                    agenda.slots[i].travelToNext = TravelEstimate(minutes: minutes, mode: mode)
                    agenda.slots[i].travelNote = travelNoteText(for: agenda.slots[i].travelToNext!)
                    updated = true
                }
            }
        }
        if updated {
            updateAgenda(agenda)
        }
    }
}

// MARK: - Private Helpers

private extension PlanViewModel {

    /// Current app language from AppState (reads UserDefaults directly to avoid coupling).
    var currentLanguage: AppLanguage {
        guard let raw = UserDefaults.standard.string(forKey: "selectedLanguage"),
              let lang = AppLanguage(rawValue: raw) else { return .en }
        return lang
    }

    /// ISO date string for a given date.
    func isoString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return f.string(from: date)
    }

    /// Effective "now" for gap analysis — midnight for future dates, real now for today.
    func effectiveNowForDate(_ date: Date) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return Date() }
        return cal.startOfDay(for: date)
    }

    // MARK: - Data Loading

    /// Load activities, lunch, and weather data if not already cached.
    @MainActor
    func loadDataPoolsIfNeeded(city: City, language: AppLanguage) async {
        // Skip if already loaded for this city
        if activitiesData != nil && lunchData != nil && weather != nil { return }

        isLoadingData = true
        defer { isLoadingData = false }

        async let activitiesTask = APIClient.shared.fetchActivities(city: city, language: language)
        async let lunchTask = APIClient.shared.fetchLunch(city: city, language: language)
        async let newsTask = APIClient.shared.fetchNews(city: city, language: language)

        do { self.activitiesData = try await activitiesTask } catch {
            // Try stale cache
            if let stale: ActivitiesResponse = await CacheManager.shared.getStale(
                ActivitiesResponse.self, key: "activities-\(city.rawValue)-\(language.rawValue)"
            ) { self.activitiesData = stale }
        }

        do { self.lunchData = try await lunchTask } catch {
            if let stale: LunchResponse = await CacheManager.shared.getStale(
                LunchResponse.self, key: "lunch-\(city.rawValue)-\(language.rawValue)"
            ) { self.lunchData = stale }
        }

        do {
            let news = try await newsTask
            self.weather = news.weather
        } catch {
            if let stale: NewsResponse = await CacheManager.shared.getStale(
                NewsResponse.self, key: "news-\(city.rawValue)-\(language.rawValue)"
            ) { self.weather = stale.weather }
        }
    }

    // MARK: - Slot / Anchor Conversion

    /// Convert an AnchorEvent to an AgendaSlot for display.
    func anchorToSlot(_ anchor: AnchorEvent) -> AgendaSlot {
        let hour = Calendar.current.component(.hour, from: anchor.startTime)
        let slotType: AgendaSlot.SlotType = {
            switch anchor.category {
            case .food:
                return hour < 15 ? .lunch : .dinner
            default:
                return .activity
            }
        }()

        let categoryLabel = anchor.category.displayName

        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "HH:mm"
        endFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        let endTimeString = endFormatter.string(from: anchor.endTime)

        return AgendaSlot(
            id: anchor.originalSlotId ?? "anchor-\(anchor.id.uuidString.prefix(8))",
            time: anchor.timeString,
            type: slotType,
            venueName: anchor.title,
            venueId: nil,
            reason: anchor.neighbourhood ?? categoryLabel,
            durationDisplay: "\(anchor.durationMinutes) min",
            tags: [categoryLabel],
            lat: anchor.lat,
            lon: anchor.lon,
            durationMinutes: anchor.durationMinutes,
            source: .userAnchor,
            isLocked: true,
            anchorEndTime: endTimeString,
            slotDate: anchor.startTime
        )
    }

    /// Convert an AgendaSlot back to an AnchorEvent for gap analysis.
    func slotToAnchor(_ slot: AgendaSlot, date: Date) -> AnchorEvent {
        let category: AnchorCategory = {
            switch slot.type {
            case .lunch, .dinner: return .food
            case .activity, .homeActivity: return .activity
            }
        }()

        let duration = slot.durationMinutes ?? {
            switch slot.type {
            case .activity: return 100
            case .lunch: return 90
            case .dinner: return 120
            case .homeActivity: return 60
            }
        }()

        return AnchorEvent(
            title: slot.venueName,
            category: category,
            startTime: slot.slotDate,
            durationMinutes: duration,
            source: slot.source == .calendar ? .calendar : .manual,
            lat: slot.lat,
            lon: slot.lon,
            originalSlotId: slot.id
        )
    }

    // MARK: - Travel Estimates

    /// Populate travel estimates between consecutive slots.
    func populateTravelEstimates(in slots: inout [AgendaSlot]) {
        // Enrich all slots with coordinates first
        for i in 0..<slots.count {
            enrichSlotCoordinates(&slots[i])
        }
        // Use haversine heuristic for initial estimates (sync)
        // MapKit directions will be fetched async and update later
        for i in 0..<slots.count {
            if i + 1 < slots.count {
                let est = TravelEstimate.estimate(
                    fromLat: slots[i].lat, fromLon: slots[i].lon,
                    toLat: slots[i + 1].lat, toLon: slots[i + 1].lon
                )
                slots[i].travelToNext = est
                slots[i].travelNote = travelNoteText(for: est)
            } else {
                slots[i].travelToNext = nil
                slots[i].travelNote = nil
            }
        }
    }

    func travelNoteText(for estimate: TravelEstimate) -> String {
        switch estimate.mode {
        case .walking: return "\(estimate.minutes) min walk"
        case .transit: return "~\(estimate.minutes) min by transit"
        }
    }

    // MARK: - Venue Coordinate Enrichment

    /// Enrich slots with coordinates from the data pools (by venueId or venue name).
    func enrichSlotCoordinates(_ slot: inout AgendaSlot) {
        guard slot.lat == nil else { return }
        // Try by venueId first
        if let venueId = slot.venueId {
            if let act = activitiesData?.activities.first(where: { $0.id == venueId }),
               let lat = act.lat, let lon = act.lon {
                slot.lat = lat
                slot.lon = lon
                return
            } else if let spot = lunchData?.spots.first(where: { $0.id == venueId }) {
                slot.lat = spot.lat
                slot.lon = spot.lon
                return
            }
        }
        // Fallback: match by venue name
        let name = slot.venueName
        if let act = activitiesData?.activities.first(where: { $0.name == name || $0.nameDE == name }),
           let lat = act.lat, let lon = act.lon {
            slot.lat = lat
            slot.lon = lon
            if slot.venueId == nil { slot.venueId = act.id }
        } else if let spot = lunchData?.spots.first(where: { $0.name == name }) {
            slot.lat = spot.lat
            slot.lon = spot.lon
            if slot.venueId == nil { slot.venueId = spot.id }
        }
    }

    // MARK: - Gap Filtering for Template Fallback

    /// Filter template-generated slots to only those matching fillable gaps,
    /// adjusting times to fit within gap windows.
    func filterSlotsToGaps(_ slots: [AgendaSlot], gaps: [FreeGap], planDate: Date) -> [AgendaSlot] {
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

        return slots
            .filter { gapForSlotID[$0.id] != nil }
            .map { slot -> AgendaSlot in
                guard let gap = gapForSlotID[slot.id] else { return slot }
                let gapStartTime = timeFormatter.string(from: gap.effectiveStart)
                let gapEndTime = timeFormatter.string(from: gap.gapEnd)
                if slot.time < gapStartTime || slot.time >= gapEndTime {
                    var adjusted = slot
                    let snappedDate = gap.effectiveStart.addingTimeInterval(15 * 60)
                    let snappedTime = timeFormatter.string(
                        from: snappedDate < gap.gapEnd ? snappedDate : gap.effectiveStart
                    )
                    adjusted.time = snappedTime
                    adjusted.slotDate = AgendaSlot.resolveSlotDate(time: snappedTime, planDate: planDate)
                    return adjusted
                }
                return slot
            }
    }

    // MARK: - Merge Helpers

    /// Merge locked slots with anchor-generated slots, deduplicating by ID or venue name.
    func mergeLockedAndAnchorSlots(locked: [AgendaSlot], anchorSlots: [AgendaSlot]) -> [AgendaSlot] {
        var result = locked
        for aSlot in anchorSlots {
            if !result.contains(where: { $0.id == aSlot.id || $0.venueName == aSlot.venueName }) {
                result.append(aSlot)
            }
        }
        result.sort { $0.time < $1.time }
        return result
    }

    // MARK: - State Mutation

    /// Update the agenda in the current state and persist to store.
    func updateAgenda(_ agenda: DayAgenda) {
        store.savePlan(agenda, city: planningCity.id, date: isoString(for: selectedDate))
        switch planState {
        case .dealt:
            planState = .dealt(agenda)
        case .saved:
            // User modified a saved plan — transition back to dealt
            planState = .dealt(agenda)
        default:
            break
        }
    }

    func recordShownVenues(_ agenda: DayAgenda) {
        for slot in agenda.slots {
            if let venueId = slot.venueId {
                recentlyShownStore.recordShown(venueId: venueId)
            }
        }
    }

    // MARK: - Theme / Weather Helpers

    func buildTheme() -> String {
        let childNames = session.children.map(\.name).joined(separator: " & ")
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE"
        let dayName = f.string(from: selectedDate)

        if let w = weather, w.temperature >= 18 {
            return "Sunny \(dayName) with \(childNames)"
        }
        return "\(dayName) plan with \(childNames)"
    }

    func weatherNoteString(_ weather: Weather?) -> String {
        guard let w = weather else { return "Weather unavailable" }
        return "\(Int(w.temperature))° and \(w.description.lowercased())"
    }

    func isBadWeather(_ weather: Weather?) -> Bool {
        guard let w = weather else { return false }
        let heavyCodes: Set<Int> = [65, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
        return w.temperature < 10 && heavyCodes.contains(w.weatherCode)
    }
}
