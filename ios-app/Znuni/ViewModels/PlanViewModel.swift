import SwiftUI
import EventKit
import CoreLocation

// MARK: - Plan State

/// State machine for the Plan tab's composition lifecycle.
enum PlanState: Equatable {
    case empty
    case calendarPreview([CalendarSlot])
    case composing(locked: [AgendaSlot])
    case dealt(DayAgenda)
    case saved(DayAgenda)
    case error(String)

    static func == (lhs: PlanState, rhs: PlanState) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty): return true
        case (.calendarPreview(let a), .calendarPreview(let b)): return a == b
        case (.composing, .composing): return true
        case (.dealt(let a), .dealt(let b)): return a.date == b.date
        case (.saved(let a), .saved(let b)): return a.date == b.date
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - PlanViewModel

/// Core orchestrator for the Plan tab. Replaces TodayViewModel's agenda composition
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

    /// Family session — loaded from UserDefaults.
    var session: FamilySession

    // MARK: - Cached Data Pools

    /// Raw data fetched from API — cached across date switches.
    private(set) var activitiesData: ActivitiesResponse?
    private(set) var lunchData: LunchResponse?
    private(set) var weather: Weather?

    /// Whether data pools are currently loading.
    var isLoadingData = false

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
    private let agendaCache = AgendaCache.shared
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
    func selectDate(_ date: Date) async {
        selectedDate = date
        let dateISO = isoString(for: date)

        // 1. Check AgendaCache for existing plan
        let anchorsHash = AgendaCache.hash(anchors: anchorStore.anchors(for: date))
        if let cachedData = await agendaCache.get(
            date: dateISO,
            city: planningCity.id,
            sessionHash: session.sessionHash,
            anchorsHash: anchorsHash
        ),
           let cached = try? JSONDecoder().decode(DayAgenda.self, from: cachedData) {
            // Determine if this was a saved plan (all slots locked) or dealt
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
            // Try cache fallback
            if let cachedData = await agendaCache.get(
                date: dateISO, city: city.id, sessionHash: session.sessionHash
            ),
               let cached = try? JSONDecoder().decode(DayAgenda.self, from: cachedData) {
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
            await cacheAgenda(agenda, dateISO: dateISO, anchors: anchors)
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
                    if !allSlots.contains(where: { $0.id == aSlot.id }) {
                        allSlots.append(aSlot)
                    }
                }
                allSlots.append(contentsOf: aiSlots)
                // Deduplicate by venue+time
                var seenAI = Set<String>()
                allSlots = allSlots.filter { slot in
                    let key = slot.venueName + slot.time
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
                await cacheAgenda(agenda, dateISO: dateISO, anchors: anchors)
                recordShownVenues(agenda)
                return
            } catch {
                #if DEBUG
                print("⚠️ AgendaComposer failed, falling back to template: \(error.localizedDescription)")
                #endif
            }
        }

        // 6. Template engine fallback
        let events = activitiesData?.cityEvents ?? []
        var result = templateEngine.buildAgenda(
            weather: effectiveWeather,
            session: session,
            activities: activities,
            restaurants: spots,
            cityEvents: events,
            recentlyShown: recentlyShownStore.recentlyShownIds(),
            language: language,
            visitStore: visitStore,
            planDate: planDate
        )

        // Gap-aware filtering: only keep slots matching fillable gaps
        var filteredSlots = filterSlotsToGaps(result.slots, gaps: fillableGaps, planDate: planDate)

        // Merge locked + anchor slots
        let anchorSlots = anchors.map { anchorToSlot($0) }
        for slot in lockedSlots {
            if !filteredSlots.contains(where: { $0.id == slot.id }) {
                filteredSlots.append(slot)
            }
        }
        for aSlot in anchorSlots {
            if !filteredSlots.contains(where: { $0.id == aSlot.id }) {
                filteredSlots.append(aSlot)
            }
        }
        // Deduplicate by venue name (template engine can produce duplicates)
        var seenVenues = Set<String>()
        filteredSlots = filteredSlots.filter { slot in
            let key = slot.venueName + slot.time
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
        await cacheAgenda(result, dateISO: dateISO, anchors: anchors)
        recordShownVenues(result)
    }

    // MARK: - Redeal

    /// Recompose unlocked slots while preserving locked ones.
    @MainActor
    func redeal() async {
        guard let current = currentAgenda else { return }
        let locked = current.slots.filter { $0.isLocked }
        ZnuniEvent.planRebuilt()
        await agendaCache.invalidate()
        recentlyShownStore.clear()
        await deal(lockedSlots: locked)
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
        guard var agenda = currentAgenda,
              let idx = agenda.slots.firstIndex(where: { $0.id == slotId }) else { return }
        agenda.slots[idx].isLocked = false
        updateAgenda(agenda)
    }

    /// Remove a slot from the current agenda. If calendar source, discard it.
    func remove(slotId: String) {
        guard var agenda = currentAgenda else { return }
        if let slot = agenda.slots.first(where: { $0.id == slotId }),
           slot.source == .calendar,
           let venueId = slot.venueId {
            calendarBridge.discardEvent(id: venueId)
        }
        agenda.slots.removeAll { $0.id == slotId }
        populateTravelEstimates(in: &agenda.slots)
        updateAgenda(agenda)
    }

    /// Replace a slot with a user-custom entry.
    func replaceWithCustom(slotId: String, name: String, start: Date, end: Date, address: String?) {
        guard var agenda = currentAgenda,
              let idx = agenda.slots.firstIndex(where: { $0.id == slotId }) else { return }

        let durationMin = Int(end.timeIntervalSince(start) / 60)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")

        agenda.slots[idx] = AgendaSlot(
            id: slotId,
            time: timeFormatter.string(from: start),
            type: agenda.slots[idx].type,
            venueName: name,
            venueId: nil,
            reason: address ?? "",
            tags: [],
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
        await cacheAgenda(agenda, dateISO: dateISO, anchors: anchors)
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
            id: "anchor-\(anchor.id.uuidString.prefix(8))",
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
            lon: slot.lon
        )
    }

    // MARK: - Travel Estimates

    /// Populate travel estimates between consecutive slots.
    func populateTravelEstimates(in slots: inout [AgendaSlot]) {
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

    /// Enrich AI-returned slots with coordinates from the data pools.
    func enrichSlotCoordinates(_ slot: inout AgendaSlot) {
        guard let venueId = slot.venueId, slot.lat == nil else { return }
        if let act = activitiesData?.activities.first(where: { $0.id == venueId }),
           let lat = act.lat, let lon = act.lon {
            slot.lat = lat
            slot.lon = lon
        } else if let spot = lunchData?.spots.first(where: { $0.id == venueId }) {
            slot.lat = spot.lat
            slot.lon = spot.lon
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

    /// Merge locked slots with anchor-generated slots, deduplicating by ID.
    func mergeLockedAndAnchorSlots(locked: [AgendaSlot], anchorSlots: [AgendaSlot]) -> [AgendaSlot] {
        var result = locked
        for aSlot in anchorSlots {
            if !result.contains(where: { $0.id == aSlot.id }) {
                result.append(aSlot)
            }
        }
        result.sort { $0.time < $1.time }
        return result
    }

    // MARK: - State Mutation

    /// Update the agenda in the current state.
    func updateAgenda(_ agenda: DayAgenda) {
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

    // MARK: - Cache

    func cacheAgenda(_ agenda: DayAgenda, dateISO: String, anchors: [AnchorEvent]) async {
        guard let encoded = try? JSONEncoder().encode(agenda) else { return }
        let anchorsHash = AgendaCache.hash(anchors: anchors)
        await agendaCache.store(
            encoded,
            date: dateISO,
            city: planningCity.id,
            sessionHash: session.sessionHash,
            anchorsHash: anchorsHash
        )
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
