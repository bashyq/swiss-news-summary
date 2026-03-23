# Trip Planner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the Plan tab to detect calendar events outside the user's home city and build a day plan around them using MKLocalSearch POIs.

**Architecture:** Calendar detection → reverse geocoding → MKLocalSearch POI discovery → existing AgendaComposer pipeline (via adapter) → same PlanSlotCard UI. Three new services (TripDetector, POISearchService, POI→Activity adapter), one new view (TripNudgeCard), and targeted changes to PlanViewModel and PlanHeroBanner.

**Tech Stack:** SwiftUI, MapKit (MKLocalSearch, MKLocalSearchCompleter), CoreLocation (CLGeocoder), EventKit, Anthropic Claude API

**Spec:** `docs/superpowers/specs/2026-03-23-trip-planner-design.md`

---

### Task 1: POISearchService — MKLocalSearch wrapper

**Files:**
- Create: `ios-app/Znuni/Services/POISearchService.swift`

This is the foundation — fetches POIs from Apple Maps for any coordinate. No dependencies on other new code.

- [ ] **Step 1: Create POIResult model and POICategory enum**

```swift
// ios-app/Znuni/Services/POISearchService.swift
import MapKit

enum POICategory: String, CaseIterable, Codable {
    case restaurant, cafe, playground, park, museum, bakery, lake

    var searchQuery: String {
        switch self {
        case .restaurant: return "restaurant"
        case .cafe: return "café"
        case .playground: return "playground"
        case .park: return "park"
        case .museum: return "museum"
        case .bakery: return "bakery"
        case .lake: return "lake beach"
        }
    }

    var pointOfInterestFilter: MKPointOfInterestFilter {
        switch self {
        case .restaurant: return MKPointOfInterestFilter(including: [.restaurant])
        case .cafe: return MKPointOfInterestFilter(including: [.cafe])
        case .playground, .lake: return MKPointOfInterestFilter(including: [.park])
        case .park: return MKPointOfInterestFilter(including: [.park, .nationalPark])
        case .museum: return MKPointOfInterestFilter(including: [.museum])
        case .bakery: return MKPointOfInterestFilter(including: [.bakery])
        }
    }
}

struct POIResult: Identifiable, Codable, Equatable {
    let id: String          // "name-lat3-lon3"
    let name: String
    let category: POICategory
    let latitude: Double
    let longitude: Double
    let url: String?
    let phoneNumber: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func stableId(name: String, lat: Double, lon: Double) -> String {
        let n = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(n)-\(String(format: "%.3f", lat))-\(String(format: "%.3f", lon))"
    }
}
```

- [ ] **Step 2: Implement POISearchService with parallel category queries**

```swift
actor POISearchService {
    static let shared = POISearchService()

    private var cache: [String: (results: [POIResult], timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 3600 // 1 hour

    func search(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = 5000
    ) async -> [POIResult] {
        let cacheKey = "\(String(format: "%.2f", coordinate.latitude))-\(String(format: "%.2f", coordinate.longitude))-\(Int(radius))"

        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.results
        }

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        var results = await withTaskGroup(of: [POIResult].self) { group in
            for category in POICategory.allCases {
                group.addTask {
                    await self.searchCategory(category, in: region)
                }
            }
            var all: [POIResult] = []
            for await batch in group {
                all.append(contentsOf: batch)
            }
            return all
        }

        results = deduplicate(results, threshold: 50)
        results.sort { distanceFrom(coordinate, to: $0) < distanceFrom(coordinate, to: $1) }

        // Retry with wider radius if too few results
        if results.count < 5 && radius < 15000 {
            return await search(near: coordinate, radius: min(radius * 2, 15000))
        }

        cache[cacheKey] = (results, Date())
        return results
    }

    private func searchCategory(_ category: POICategory, in region: MKCoordinateRegion) async -> [POIResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.searchQuery
        request.region = region
        request.resultTypes = .pointOfInterest

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems.compactMap { item in
                guard let name = item.name else { return nil }
                let lat = item.placemark.coordinate.latitude
                let lon = item.placemark.coordinate.longitude
                return POIResult(
                    id: POIResult.stableId(name: name, lat: lat, lon: lon),
                    name: name,
                    category: category,
                    latitude: lat,
                    longitude: lon,
                    url: item.url?.absoluteString,
                    phoneNumber: item.phoneNumber
                )
            }
        } catch {
            return []
        }
    }

    private func deduplicate(_ results: [POIResult], threshold: Double) -> [POIResult] {
        var unique: [POIResult] = []
        for result in results {
            let isDuplicate = unique.contains { existing in
                let dist = TravelEstimate.haversine(
                    lat1: existing.latitude, lon1: existing.longitude,
                    lat2: result.latitude, lon2: result.longitude
                )
                return dist < threshold && existing.name.lowercased() == result.name.lowercased()
            }
            if !isDuplicate {
                unique.append(result)
            }
        }
        return unique
    }

    private func distanceFrom(_ center: CLLocationCoordinate2D, to poi: POIResult) -> Double {
        TravelEstimate.haversine(
            lat1: center.latitude, lon1: center.longitude,
            lat2: poi.latitude, lon2: poi.longitude
        )
    }
}
```

- [ ] **Step 3: Build in Xcode, verify no compilation errors**

Run: Cmd+B in Xcode
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add ios-app/Znuni/Services/POISearchService.swift
git commit -m "feat: add POISearchService — MKLocalSearch wrapper with caching and dedup"
```

---

### Task 2: POI → Activity/LunchSpot adapter

**Files:**
- Create: `ios-app/Znuni/Services/POIAdapter.swift`

Converts MKLocalSearch results into Activity/LunchSpot objects so the existing AgendaComposer pipeline works without changes.

- [ ] **Step 1: Create adapter with toActivity() and toLunchSpot()**

```swift
// ios-app/Znuni/Services/POIAdapter.swift
import Foundation

struct POIAdapter {
    /// Convert POI results into Activity and LunchSpot pools for AgendaComposer
    static func buildPools(from pois: [POIResult]) -> (activities: [Activity], lunches: [LunchSpot], dinners: [LunchSpot]) {
        var activities: [Activity] = []
        var lunches: [LunchSpot] = []
        var dinners: [LunchSpot] = []

        for poi in pois {
            switch poi.category {
            case .restaurant, .cafe:
                let spot = poi.toLunchSpot()
                lunches.append(spot)
                dinners.append(spot)
            case .playground, .park, .museum, .bakery, .lake:
                activities.append(poi.toActivity())
            }
        }

        return (activities, lunches, dinners)
    }
}

extension POIResult {
    func toActivity() -> Activity {
        let isIndoor: Bool
        switch category {
        case .museum, .bakery, .cafe: isIndoor = true
        case .playground, .park, .lake: isIndoor = false
        case .restaurant: isIndoor = true
        }

        return Activity(
            id: id,
            name: name,
            nameDE: name,  // No translation available
            description: "Nearby \(category.rawValue) in the area",
            descriptionDE: "\(category.rawValue.capitalized) in der Nähe",
            indoor: isIndoor,
            ageRange: "0-99",
            duration: "60",
            price: nil,
            priceDE: nil,
            url: url,
            lat: latitude,
            lon: longitude,
            category: category.rawValue,
            minAge: nil,
            maxAge: nil,
            season: nil,
            free: category == .playground || category == .park || category == .lake,
            recurring: nil,
            stayHome: false,
            availableMonths: nil,
            subcategory: nil,
            materials: nil,
            materialsDE: nil,
            addedDate: nil,
            suggestibility: "always"
        )
    }

    func toLunchSpot() -> LunchSpot {
        return LunchSpot(
            id: id,
            name: name,
            lat: latitude,
            lon: longitude,
            cuisine: category == .cafe ? "cafe" : nil,
            cuisineCategory: category == .cafe ? "cafe" : nil,
            wheelchair: nil,
            outdoorSeating: nil,
            takeaway: nil,
            openingHours: nil,
            openForLunch: true,
            openForDinner: true,
            kidFriendly: nil,
            vegetarian: nil,
            vegan: nil,
            phone: phoneNumber,
            website: url,
            amenity: category == .cafe ? "cafe" : "restaurant",
            rating: nil,
            ratingCount: nil,
            permanentlyClosed: false
        )
    }
}
```

- [ ] **Step 2: Build in Xcode, verify no compilation errors**

Run: Cmd+B in Xcode
Expected: Build succeeds. The Activity and LunchSpot initializers must match exactly — fix any missing/extra fields.

- [ ] **Step 3: Commit**

```bash
git add ios-app/Znuni/Services/POIAdapter.swift
git commit -m "feat: add POIAdapter — converts MKLocalSearch POIs to Activity/LunchSpot"
```

---

### Task 3: TripDetector — calendar event geocoding

**Files:**
- Create: `ios-app/Znuni/Services/TripDetector.swift`

Scans calendar events, reverse-geocodes locations, identifies away-from-home events.

- [ ] **Step 1: Create DetectedTrip model and TripDetector service**

```swift
// ios-app/Znuni/Services/TripDetector.swift
import EventKit
import CoreLocation

struct DetectedTrip: Equatable, Identifiable {
    let id: String                          // calendarItemExternalIdentifier or synthetic
    let calendarEvent: EKEvent?
    let locality: String                    // "Meggen", "Grindelwald"
    let coordinate: CLLocationCoordinate2D
    let startTime: Date?                    // nil = full day free (Sunshine/Snow CTA)
    let endTime: Date?
    let eventTitle: String

    static func == (lhs: DetectedTrip, rhs: DetectedTrip) -> Bool {
        lhs.id == rhs.id
    }

    /// Synthetic trip for Sunshine/Snow CTA (no calendar event)
    static func synthetic(locality: String, coordinate: CLLocationCoordinate2D) -> DetectedTrip {
        DetectedTrip(
            id: "synthetic-\(locality.lowercased())",
            calendarEvent: nil,
            locality: locality,
            coordinate: coordinate,
            startTime: nil,
            endTime: nil,
            eventTitle: locality
        )
    }
}

actor TripDetector {
    static let shared = TripDetector()

    private let geocoder = CLGeocoder()
    private var geocodeCache: [String: String] = [:]   // "lat3-lon3" → locality

    /// Detect away-from-home calendar events for a given date
    func detectTrips(
        for date: Date,
        homeCity: City,
        calendarEvents: [EKEvent]
    ) async -> [DetectedTrip] {
        let eventsWithLocation = calendarEvents.filter { event in
            event.structuredLocation?.geoLocation != nil
        }

        var trips: [DetectedTrip] = []

        for event in eventsWithLocation {
            guard let geoLocation = event.structuredLocation?.geoLocation else { continue }
            let coord = geoLocation.coordinate

            // Check distance first (>5km from home city)
            let distanceKm = TravelEstimate.haversine(
                lat1: homeCity.coordinate.latitude,
                lon1: homeCity.coordinate.longitude,
                lat2: coord.latitude,
                lon2: coord.longitude
            ) / 1000.0

            guard distanceKm > 5.0 else { continue }

            // Reverse geocode (serial, cached)
            guard let locality = await reverseGeocode(coordinate: coord) else { continue }

            // Compare locality to home city
            let homeName = homeCity.displayName.lowercased()
            guard locality.lowercased() != homeName else { continue }

            // Skip if this is one of the 7 curated cities (handled by existing flow)
            let isCurated = City.allCases.contains { city in
                city.displayName.lowercased() == locality.lowercased() ||
                city.displayNameDE.lowercased() == locality.lowercased()
            }
            guard !isCurated else { continue }

            trips.append(DetectedTrip(
                id: event.calendarItemExternalIdentifier,
                calendarEvent: event,
                locality: locality,
                coordinate: coord,
                startTime: event.startDate,
                endTime: event.endDate,
                eventTitle: event.title ?? locality
            ))
        }

        // Group by locality, keep chronologically first
        var seen: Set<String> = []
        return trips.filter { trip in
            let key = trip.locality.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        let cacheKey = "\(String(format: "%.3f", coordinate.latitude))-\(String(format: "%.3f", coordinate.longitude))"

        if let cached = geocodeCache[cacheKey] {
            return cached
        }

        // Serial with delay to respect CLGeocoder rate limits
        try? await Task.sleep(for: .seconds(1))

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let locality = placemarks.first?.locality
            if let locality {
                geocodeCache[cacheKey] = locality
            }
            return locality
        } catch {
            return nil
        }
    }

    /// Prefetch trips for a date range (e.g. the 14-day date strip)
    func prefetchTrips(
        dates: [Date],
        homeCity: City,
        calendarService: CalendarService
    ) async -> [String: [DetectedTrip]] {
        var result: [String: [DetectedTrip]] = [:]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        for date in dates {
            let events = calendarService.fetchEvents(for: date)
            let trips = await detectTrips(for: date, homeCity: homeCity, calendarEvents: events)
            if !trips.isEmpty {
                result[formatter.string(from: date)] = trips
            }
        }
        return result
    }
}
```

- [ ] **Step 2: Build in Xcode, verify no compilation errors**

Run: Cmd+B in Xcode
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add ios-app/Znuni/Services/TripDetector.swift
git commit -m "feat: add TripDetector — geocodes calendar events, detects away-from-home trips"
```

---

### Task 4: TripNudgeCard view

**Files:**
- Create: `ios-app/Znuni/Views/Today/TripNudgeCard.swift`

Navy-styled card shown when an away event is detected.

- [ ] **Step 1: Create TripNudgeCard view**

```swift
// ios-app/Znuni/Views/Today/TripNudgeCard.swift
import SwiftUI

struct TripNudgeCard: View {
    let trip: DetectedTrip
    let onPlan: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Eyebrow
            Text("AWAY FROM HOME")
                .font(.znEyebrow)
                .foregroundStyle(.white.opacity(0.6))

            // Title
            Text("\(trip.eventTitle) in \(trip.locality)")
                .font(.cardHeadline)
                .foregroundStyle(.white)

            // Free time subtitle
            if let freeTimeText = freeTimeDescription {
                Text(freeTimeText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Action buttons
            HStack(spacing: 10) {
                Button(action: onPlan) {
                    Text("Plan my day in \(trip.locality)")
                        .font(.znLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.znLabel)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .fill(Color.znNavy)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .padding(.horizontal, 16)
    }

    private var freeTimeDescription: String? {
        guard let start = trip.startTime, let end = trip.endTime else {
            return "Explore the area for the whole day"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        return "You're free before \(startStr) and after \(endStr)"
    }
}
```

- [ ] **Step 2: Build in Xcode, verify no compilation errors**

Run: Cmd+B in Xcode
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add ios-app/Znuni/Views/Today/TripNudgeCard.swift
git commit -m "feat: add TripNudgeCard — navy card for detected away-from-home events"
```

---

### Task 5: PlanViewModel — add trip state and dealTrip()

**Files:**
- Modify: `ios-app/Znuni/ViewModels/PlanViewModel.swift`

Add `.tripDetected` state, trip detection in `selectDate()`, and `dealTrip()` method.

- [ ] **Step 1: Add `tripDetected` case to PlanState enum**

In `PlanViewModel.swift`, find the `PlanState` enum (around line 12) and add:

```swift
case tripDetected(DetectedTrip)
```

after `calendarPreview`.

- [ ] **Step 2: Add trip-related properties to PlanViewModel**

Add these properties to the class (after the existing properties, around line 64):

```swift
// Trip planner
private(set) var detectedTrip: DetectedTrip?
private var tripDismissals: Set<String> {
    get { Set(UserDefaults.standard.stringArray(forKey: "tripDismissals") ?? []) }
    set { UserDefaults.standard.set(Array(newValue), forKey: "tripDismissals") }
}
var isTripMode: Bool { detectedTrip != nil }
var tripLocality: String? { detectedTrip?.locality }
```

- [ ] **Step 3: Update selectDate() to detect trips**

In `selectDate()` (around line 102), after loading from store and before checking calendar events, add trip detection. The priority order should be:

1. Saved plan in store → `.dealt`
2. Trip detected → `.tripDetected`
3. Calendar events (local) → `.calendarPreview`
4. No events → `.empty`

Find the section after the store check and before the calendar check. Add:

```swift
// Check for away-from-home calendar events
let allCalendarEvents = CalendarService.shared.fetchEvents(for: date)
let trips = await TripDetector.shared.detectTrips(
    for: date,
    homeCity: planningCity.city,
    calendarEvents: allCalendarEvents
)

if let trip = trips.first, !tripDismissals.contains(trip.id) {
    detectedTrip = trip
    planState = .tripDetected(trip)
    return
}

detectedTrip = nil
```

- [ ] **Step 4: Add dealTrip() method**

Add this method after the existing `deal()` method (around line 330):

```swift
/// Compose a day plan for a trip destination using MKLocalSearch POIs
func dealTrip(_ trip: DetectedTrip) async {
    let lockedSlots: [AgendaSlot] = []
    planState = .composing(locked: lockedSlots)
    detectedTrip = trip

    // 1. Fetch POIs near destination
    let pois = await POISearchService.shared.search(near: trip.coordinate)
    let pools = POIAdapter.buildPools(from: pois)

    // 2. Fetch weather for destination
    let tripWeather = await fetchWeatherForCoordinate(trip.coordinate)

    // 3. Build anchors from calendar event
    var anchors: [AnchorEvent] = []
    if let event = trip.calendarEvent, let start = trip.startTime, let end = trip.endTime {
        anchors.append(AnchorEvent(
            id: UUID(),
            title: trip.eventTitle,
            category: .errand,
            startTime: start,
            durationMinutes: Int(end.timeIntervalSince(start) / 60),
            source: .calendar,
            calendarEventId: event.calendarItemExternalIdentifier,
            createdDate: Date()
        ))
    }

    // 4. Gap analysis
    let now = effectiveNowForDate(selectedDate)
    let gaps = GapAnalysisEngine.analyse(anchors: anchors, now: now, date: selectedDate)
    let fillableGaps = gaps.filter { $0.isFillable }

    guard !fillableGaps.isEmpty else {
        // No gaps to fill — just show the anchor
        let anchorSlots = anchors.map { anchorToSlot($0) }
        let agenda = DayAgenda(
            date: isoString(for: selectedDate),
            theme: "Your day in \(trip.locality)",
            weatherNote: weatherNoteString(tripWeather),
            badWeatherMode: isBadWeather(tripWeather),
            slots: anchorSlots,
            homeActivities: nil
        )
        planState = .dealt(agenda)
        store.savePlan(agenda, city: "trip-\(trip.locality.lowercased())", date: isoString(for: selectedDate))
        return
    }

    // 5. Compose via AgendaComposer (or fallback)
    var slots: [AgendaSlot] = []
    let apiKey = Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String ?? ""

    if !apiKey.isEmpty {
        do {
            slots = try await AgendaComposer.compose(
                gaps: fillableGaps,
                activities: pools.activities,
                lunches: pools.lunches,
                dinners: pools.dinners,
                weather: tripWeather,
                session: session,
                language: currentLanguage,
                apiKey: apiKey,
                planDate: selectedDate
            )
        } catch {
            // Fallback: distance-sorted POI assignment
            slots = buildFallbackSlots(gaps: fillableGaps, pois: pois, planDate: selectedDate)
        }
    } else {
        slots = buildFallbackSlots(gaps: fillableGaps, pois: pois, planDate: selectedDate)
    }

    // 6. Merge anchors + AI slots
    let anchorSlots = anchors.map { anchorToSlot($0) }
    var allSlots = anchorSlots + slots
    allSlots.sort { $0.time < $1.time }

    // 7. Travel estimates
    populateTravelEstimates(in: &allSlots)

    let agenda = DayAgenda(
        date: isoString(for: selectedDate),
        theme: "Your day in \(trip.locality)",
        weatherNote: weatherNoteString(tripWeather),
        badWeatherMode: isBadWeather(tripWeather),
        slots: allSlots,
        homeActivities: nil
    )

    planState = .dealt(agenda)
    store.savePlan(agenda, city: "trip-\(trip.locality.lowercased())", date: isoString(for: selectedDate))

    // Async: enrich travel times via MapKit
    Task { await fetchMapKitTravelTimes() }
}

// Note: AgendaComposer.compose() will receive POI-adapted Activity/LunchSpot objects.
// The venue names come from Apple Maps, so Claude will naturally reference real places.
// No system prompt change needed for v1 — the POI descriptions ("Nearby playground in the area")
// provide enough context. If results feel generic, add a tripContext parameter in a follow-up.

/// Fallback when Claude API is unavailable: assign nearest POIs by gap type
private func buildFallbackSlots(gaps: [FreeGap], pois: [POIResult], planDate: Date) -> [AgendaSlot] {
    var used: Set<String> = []
    var slots: [AgendaSlot] = []

    for gap in gaps {
        let targetCategories: [POICategory]
        let slotType: AgendaSlot.SlotType

        switch gap.suggestedType {
        case .lunch:
            targetCategories = [.restaurant, .cafe]
            slotType = .lunch
        case .dinner:
            targetCategories = [.restaurant]
            slotType = .dinner
        default:
            targetCategories = [.playground, .park, .museum, .lake, .bakery]
            slotType = .activity
        }

        if let poi = pois.first(where: { targetCategories.contains($0.category) && !used.contains($0.id) }) {
            used.insert(poi.id)
            let time = gap.effectiveStart
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.timeZone = TimeZone(identifier: "Europe/Zurich")

            slots.append(AgendaSlot(
                id: gap.type.rawValue,
                time: formatter.string(from: time),
                type: slotType,
                venueName: poi.name,
                venueId: poi.id,
                reason: "Nearby \(poi.category.rawValue)",
                durationDisplay: nil,
                travelNote: nil,
                tags: [poi.category.rawValue.capitalized],
                lat: poi.latitude,
                lon: poi.longitude,
                venueUrl: poi.url,
                travelToNext: nil,
                weatherAtSlot: nil,
                durationMinutes: slotType == .activity ? 100 : 90,
                checkOutTime: nil,
                wasAutoCheckedIn: false,
                source: .aiGenerated,
                isLocked: false,
                customVenueName: nil,
                customNeighbourhood: nil,
                isStale: false,
                anchorEndTime: nil,
                slotDate: AgendaSlot.resolveSlotDate(time: formatter.string(from: time), planDate: planDate)
            ))
        }
    }

    return slots
}

/// Fetch weather for an arbitrary coordinate (trip destination)
private func fetchWeatherForCoordinate(_ coordinate: CLLocationCoordinate2D) async -> Weather? {
    let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&current_weather=true&timezone=Europe/Zurich"
    guard let url = URL(string: urlString) else { return nil }

    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        struct OpenMeteoResponse: Decodable {
            let current_weather: CurrentWeather
            struct CurrentWeather: Decodable {
                let temperature: Double
                let weathercode: Int
                let windspeed: Double
            }
        }
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let cw = response.current_weather
        return Weather(
            temperature: cw.temperature,
            description: "",
            weatherCode: cw.weathercode,
            windSpeed: cw.windspeed,
            hourly: nil
        )
    } catch {
        return nil
    }
}
```

- [ ] **Step 5: Add dismissTrip() method**

```swift
func dismissTrip(_ trip: DetectedTrip) {
    tripDismissals.insert(trip.id)
    detectedTrip = nil
    // Fall through to normal state
    Task {
        await selectDate(selectedDate)
    }
}
```

- [ ] **Step 6: Build in Xcode, verify no compilation errors**

Run: Cmd+B in Xcode
Expected: Build succeeds. May need to adjust initializer calls if AgendaSlot or AnchorEvent init signatures differ — check and fix.

- [ ] **Step 7: Commit**

```bash
git add ios-app/Znuni/ViewModels/PlanViewModel.swift
git commit -m "feat: add tripDetected state, dealTrip(), and trip detection in selectDate"
```

---

### Task 6: PlanTabView — render trip state

**Files:**
- Modify: `ios-app/Znuni/Views/Today/PlanTabView.swift`

Add `.tripDetected` case rendering to the state machine switch.

- [ ] **Step 1: Add tripDetected case to planContent switch**

In `PlanTabView.swift`, find the `planContent` switch (around line 124-142). Add a new case:

```swift
case .tripDetected(let trip):
    tripDetectedState(trip)
```

- [ ] **Step 2: Add tripDetectedState view builder**

Add this method alongside the other state renderers (after `calendarPreviewState`, around line 204):

```swift
@ViewBuilder
private func tripDetectedState(_ trip: DetectedTrip) -> some View {
    TripNudgeCard(
        trip: trip,
        onPlan: {
            Task {
                await viewModel.dealTrip(trip)
            }
        },
        onDismiss: {
            viewModel.dismissTrip(trip)
        }
    )
    .transition(.opacity.combined(with: .move(edge: .top)))
}
```

- [ ] **Step 3: Build in Xcode, verify no compilation errors**

Run: Cmd+B in Xcode
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add ios-app/Znuni/Views/Today/PlanTabView.swift
git commit -m "feat: render TripNudgeCard in PlanTabView for tripDetected state"
```

---

### Task 7: PlanHeroBanner — trip mode title

**Files:**
- Modify: `ios-app/Znuni/Views/Today/PlanHeroBanner.swift`

Adapt hero banner title and city display for trip mode.

- [ ] **Step 1: Add trip properties to PlanHeroBanner**

The banner needs to know if we're in trip mode. Add a property:

```swift
var tripLocality: String?
```

- [ ] **Step 2: Update title text for trip mode**

In the `titleText` computed property (around line 89), add a trip mode branch:

```swift
if let locality = tripLocality {
    // Trip mode: "Your day in Meggen"
    // Use "Your day in" prefix with locality in italic Playfair
}
```

The exact implementation depends on the current title structure — wrap the existing logic in an `if/else` checking `tripLocality`.

- [ ] **Step 3: Update city picker for trip mode**

In the city picker button (around line 182), when `tripLocality` is set, show the trip locality name instead of the city picker menu. The trip destination isn't switchable — it's fixed by the calendar event.

```swift
if let locality = tripLocality {
    // Show locality as static glass pill (no menu)
    Text(locality)
        .font(.znLabel)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
} else {
    // Existing city picker menu
}
```

- [ ] **Step 4: Wire tripLocality from PlanViewModel in PlanTabView**

In `PlanTabView.swift`, pass `viewModel.tripLocality` to `PlanHeroBanner`:

```swift
PlanHeroBanner(
    // ... existing params ...
    tripLocality: viewModel.tripLocality
)
```

- [ ] **Step 5: Build in Xcode, verify no compilation errors**

Run: Cmd+B in Xcode
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add ios-app/Znuni/Views/Today/PlanHeroBanner.swift ios-app/Znuni/Views/Today/PlanTabView.swift
git commit -m "feat: adapt hero banner for trip mode — locality title + static city pill"
```

---

### Task 8: FreshnessScorer — bypass curated-only checks for POI data

**Files:**
- Modify: `ios-app/Znuni/Services/FreshnessScorer.swift`

POI-sourced activities don't have `suggestibility`, `availableMonths`, or `season` fields set meaningfully. The scorer's hard exclusions would incorrectly filter them out.

- [ ] **Step 1: Add POI-aware check to scoreActivity()**

In `FreshnessScorer.scoreActivity()` (around line 22), the hard exclusions section checks `isFeedOnly`, seasonal availability, and opening hours. POI activities have `suggestibility = "always"` and no seasonal data, so most checks pass naturally. But verify that:

1. `isFeedOnly` returns false for `suggestibility = "always"` — check `Activity.isFeedOnly` computed property
2. `isCurrentSeason` returns true when `season` is nil
3. `isAvailable(on:)` returns true when `availableMonths` is nil

If all three are already true (likely based on the code), no changes needed. Just verify and document.

- [ ] **Step 2: Verify scoreRestaurant() works with POI LunchSpots**

POI-adapted LunchSpots have `rating = nil` and `ratingCount = nil`. The scorer's hard rules require `rating >= 4.0` and `ratingCount >= 10`. This would exclude ALL POI restaurants.

Fix: In `scoreRestaurant()`, skip the rating/ratingCount checks when both are nil:

```swift
// Skip rating filter for POI-sourced restaurants (no rating data available)
if let rating = restaurant.rating, rating < 4.0 { return ineligible }
if let count = restaurant.ratingCount, count < 10 { return ineligible }
```

Check if this is already using optional chaining — if so, no change needed.

- [ ] **Step 3: Build and verify**

Run: Cmd+B in Xcode
Expected: Build succeeds

- [ ] **Step 4: Commit (only if changes were needed)**

```bash
git add ios-app/Znuni/Services/FreshnessScorer.swift
git commit -m "fix: FreshnessScorer accepts POI-sourced venues without ratings"
```

---

### Task 9: Sunshine/Snow CTA — route non-curated destinations through trip planner

**Files:**
- Modify: `ios-app/Znuni/ViewModels/SunshineViewModel.swift` (or wherever "Plan a day here" is handled)
- Modify: `ios-app/Znuni/App/AppState.swift`

Currently, the "Plan a day here" CTA is gated to curated cities via `PlanningCity.isCovered()`. Remove this gate for non-curated destinations and route them through trip planner.

- [ ] **Step 1: Find the "Plan a day here" button and its gate**

Search for `isCovered` or `pendingPlanRequest` in the Sunshine/Snow views. The button likely checks `PlanningCity.isCovered(destinationId)` and hides itself for non-curated destinations.

- [ ] **Step 2: Show the button for all destinations**

Remove or bypass the `isCovered` gate. For non-curated destinations, set a new `AppState` property:

```swift
// In AppState.swift, add:
var pendingTripRequest: DetectedTrip?
```

When the CTA is tapped for a non-curated destination:

```swift
// In the Sunshine/Snow view:
if PlanningCity.isCovered(destination.id) {
    // Existing flow: set pendingPlanRequest
    appState.pendingPlanRequest = PlanRequest(cityId: destination.id, date: selectedDate)
} else {
    // Trip flow: create synthetic DetectedTrip
    appState.pendingTripRequest = DetectedTrip.synthetic(
        locality: destination.name,
        coordinate: CLLocationCoordinate2D(latitude: destination.lat, longitude: destination.lon)
    )
}
appState.selectedTab = .today
```

- [ ] **Step 3: Handle pendingTripRequest in PlanTabView/PlanViewModel**

In `PlanTabView.swift`, check for `pendingTripRequest` on appear (similar to how `pendingPlanRequest` is handled):

```swift
.onChange(of: appState.pendingTripRequest) { _, request in
    guard let trip = request else { return }
    appState.pendingTripRequest = nil
    Task {
        await viewModel.dealTrip(trip)
    }
}
```

- [ ] **Step 4: Build and verify**

Run: Cmd+B in Xcode
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add ios-app/Znuni/ViewModels/SunshineViewModel.swift ios-app/Znuni/App/AppState.swift ios-app/Znuni/Views/Today/PlanTabView.swift
git commit -m "feat: route non-curated Sunshine/Snow destinations through trip planner"
```

---

### Task 10: Integration testing and polish

**Files:**
- Modify: Various files as needed for bug fixes

Manual verification of all flows end-to-end.

- [ ] **Step 1: Test calendar detection flow**

1. Add a calendar event with a location outside your home city (e.g. "Meeting — Rapperswil" with Rapperswil as location)
2. Open the app, go to Plan tab, select that date
3. Verify: TripNudgeCard appears with event title and locality
4. Tap "Plan my day in Rapperswil"
5. Verify: Cards are dealt with MKLocalSearch POIs (restaurants, parks, etc.)
6. Verify: Hero banner shows "Your day in Rapperswil"
7. Verify: Lock/unlock/remove work on dealt cards

- [ ] **Step 2: Test dismiss flow**

1. Tap "Dismiss" on the nudge card
2. Verify: Card disappears, normal Plan tab state shown
3. Switch dates and come back
4. Verify: Nudge stays dismissed for that event

- [ ] **Step 3: Test fallback (no API key)**

1. Temporarily clear the Anthropic API key
2. Trigger a trip plan
3. Verify: Fallback distance-sorted POI slots are dealt (not a crash)

- [ ] **Step 4: Test curated city exclusion**

1. Add a calendar event in one of the 7 curated cities (e.g. Basel)
2. Verify: No trip nudge appears (handled by existing flow)

- [ ] **Step 5: Test edge cases**

1. Calendar event with no location → no nudge
2. Calendar event <5km from home → no nudge
3. Rural location with few POIs → verify radius widening works
4. Multiple away events same day → only first shown

- [ ] **Step 6: Fix any issues found, commit**

```bash
git add -A
git commit -m "fix: integration test fixes for trip planner"
```

- [ ] **Step 7: Final build verification**

Run: Cmd+B in Xcode (clean build)
Expected: Build succeeds with no warnings related to trip planner code
