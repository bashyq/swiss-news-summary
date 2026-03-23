# Trip Planner Design Spec

## Overview

Extend the Plan tab to support planning a day in any destination — not just the 7 curated cities. The app detects calendar events outside the user's home city and offers to build a day plan around them using on-device POI discovery (MKLocalSearch).

## User Scenarios

1. **Flat viewing**: You have a 2pm flat viewing in Rapperswil. The app detects the event, offers to plan the rest of the day — playground in the morning, lunch nearby, the viewing, then a lakeside walk.
2. **Doctor appointment**: Your wife has an eye doctor appointment in Meggen at 10am. Nice area — what else is there? The app fills the gaps: café before, playground after, lunch spot.
3. **Family visit**: Father-in-law invites you to Grindelwald. You add a calendar event "Lunch at Opa's — Grindelwald", the app detects it and suggests morning/afternoon activities in the area.

## Entry Points

### Primary: Calendar Detection

On Plan tab load (and date change), the app scans calendar events for the selected date:

1. Filter events that have a `structuredLocation` with coordinates
2. Reverse-geocode each location via `CLGeocoder` → extract `locality` name
3. Compare locality to user's home city (from `AppState.city`)
4. If locality differs AND distance > 5km from home city center → this is an **away event**
5. Show a `TripNudgeCard` on the Plan tab with event details and a "Plan my day in [locality]" CTA

**Detection criteria**: Two checks — (1) locality name differs from home city (case-insensitive), AND (2) distance from home city center > 5km. The distance check prevents false positives for nearby suburbs (e.g. "Kloten" is 10km from Zürich center → trip; "Zürich-Oerlikon" resolves to locality "Zürich" → not a trip).

**Geocoding constraints**: `CLGeocoder` must be called serially with ~1s delay between calls. Cache results keyed by coordinate (rounded to 3 decimal places, ~100m precision) to avoid repeated lookups across date switches.

### Secondary: Sunshine / Snow CTA

Existing "Plan a day here" buttons on Sunshine/Snow destination cards already set `AppState.pendingPlanRequest`. Currently gated to the 7 supported cities — remove this gate. For non-curated destinations, create a synthetic `DetectedTrip` with no anchor event (the entire day is free time) and route through `dealTrip()`. The gap analysis returns the full day as free gaps.

### Workaround: Manual Calendar Event

For trips without existing calendar events (e.g. spontaneous Grindelwald invite), the user adds a calendar event with a location. The detection picks it up on the next Plan tab load.

## Architecture

### Flow: "Plan my day in Meggen"

```
User taps TripNudgeCard CTA
  → POISearchService.search(near: destination, radius: ~5km)
     → Parallel MKLocalSearch queries:
        - Restaurants
        - Cafés
        - Playgrounds
        - Parks & Gardens
        - Museums
        - Bakeries / Ice Cream
        - Lakes / Beaches
     → Deduplicate, normalize into POI pool
     → Cache results (keyed by coordinate+radius, TTL 1 hour)
  → WeatherService.fetch(lat:lon:date:) — Open-Meteo, already client-side
  → GapAnalysisEngine.analyse() — calendar event = anchor, find free windows
  → AgendaComposer.compose() — Claude picks from POI pool, weather-aware
     → Falls back to distance-sorted POI list if no API key (see Fallback section)
  → Deal cards with stagger animation (same as today)
```

### State Machine Update

The existing `PlanState` gains one new state. Priority order in `selectDate`:

```
1. Saved plan exists in PlanStore   → .dealt (restored)
2. Trip detected (away-event)       → .tripDetected(DetectedTrip)
3. Calendar events (local)          → .calendarPreview([CalendarSlot])
4. No events                        → .empty
```

Transitions from `.tripDetected`:
- User taps "Plan my day" CTA → `.composing` → `.dealt`
- User taps "Dismiss" → `.calendarPreview` or `.empty` (falls through to normal flow)
- User switches date → re-evaluate from step 1

**Calendar lock/unlock in trip mode**: When transitioning from `.tripDetected` to `.composing`, the away-event(s) become anchors automatically (locked). Other local calendar events for that date are included in the calendar preview within the dealt cards, same as today — user can unlock/remove them.

### What Changes

| Component | Current (7 cities) | Trip (any destination) |
|-----------|-------------------|----------------------|
| POI data source | Worker API (curated activities) | MKLocalSearch (dynamic) |
| Restaurant data | Worker /lunch endpoint | MKLocalSearch (restaurants) |
| Weather | Open-Meteo client-side | Same — any lat/lon |
| Gap analysis | GapAnalysisEngine | Same — city-agnostic |
| Composer | AgendaComposer (Claude) | Same — adapter converts POIs (see below) |
| FreshnessScorer | Curated activity IDs | `name-lat3-lon3` stable key (see below) |
| Photos | R2 curated photos | Gradient + icon fallback (no photos) |
| Persistence | PlanStore (city-date key) | Same — `trip-{locality}` as city key |
| UI cards | PlanSlotCard | Same |
| Hero banner | "Plan your Monday" | "Your day in Meggen" |

### What Stays the Same

- PlanStore persistence (write-through memory+disk, keyed by city+date)
- PlanSlotCard UI (lock/unlock/remove/replace/expand/collapse)
- Travel connectors (haversine + async MKDirections)
- Calendar export (save to calendar with venue location)
- Custom slot replacement with geocoding
- Date strip navigation

## New Components

### TripDetector (Service)

Scans calendar events for a given date range, geocodes locations, returns detected away-events.

```swift
struct DetectedTrip {
    let calendarEvent: EKEvent?     // nil for Sunshine/Snow CTA (synthetic trip)
    let locality: String            // "Meggen", "Grindelwald"
    let coordinate: CLLocationCoordinate2D
    let startTime: Date?            // nil = full day free
    let endTime: Date?              // nil = full day free
}

class TripDetector {
    func detectTrips(
        for date: Date,
        homeCity: City,
        calendarEvents: [EKEvent]
    ) async -> [DetectedTrip]
}
```

**Logic:**
- Filter events with `structuredLocation?.geoLocation`
- Reverse-geocode serially (1s delay between calls) via `CLGeocoder`
- Cache geocode results keyed by rounded coordinate (3 decimal places)
- Compare `locality` to `homeCity.displayName` (case-insensitive) AND check distance > 5km
- If event is in one of the 7 curated cities → skip (handled by existing flow with curated data)
- If multiple away-events in same locality → group into single `DetectedTrip`
- V1: show nudge for chronologically first away-event in a non-curated locality

### POISearchService (Service)

Wraps MKLocalSearch for multi-category POI discovery.

```swift
struct POIResult {
    let id: String                  // Stable key: "name-lat3-lon3" (name + 3-decimal coords)
    let name: String
    let category: POICategory       // .restaurant, .cafe, .playground, .park, .museum, .bakery, .lake
    let coordinate: CLLocationCoordinate2D
    let url: URL?
    let phoneNumber: String?
    let pointOfInterestCategory: MKPointOfInterestCategory?
}

enum POICategory: String, CaseIterable {
    case restaurant, cafe, playground, park, museum, bakery, lake
}

class POISearchService {
    func search(
        near coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = 5000
    ) async -> [POIResult]
}
```

**ID strategy**: `POIResult.id` is `"\(name.lowercased())-\(lat, 3dp)-\(lon, 3dp)"`. This is stable across sessions (unlike `MKMapItem.identifier`) and used by FreshnessScorer.

**Logic:**
- Run parallel `MKLocalSearch.Request` for each `POICategory`
- Map MKPointOfInterestCategory to POICategory
- Deduplicate by proximity (within 50m) + name similarity
- Return unified pool, sorted by distance from destination center
- Cache results keyed by `"\(lat, 2dp)-\(lon, 2dp)-\(radius)"`, TTL 1 hour
- If results < 5 for initial radius, retry with 10km, then 15km

### TripNudgeCard (View)

Navy-styled card shown on Plan tab when an away-event is detected. Matches the design language of existing calendar preview cards.

**Content:**
- Eyebrow: "📍 Away from home"
- Title: event title + locality ("Eye doctor in Meggen")
- Subtitle: free time windows ("You're free before 10:00 and after 11:30")
- CTA: glass button "Plan my day in Meggen"
- Dismiss button (stores dismissal so it doesn't reappear)

**Dismissal persistence**: `UserDefaults` set keyed by `EKEvent.calendarItemExternalIdentifier`. No date component — if the event is dismissed, it stays dismissed even if the event moves dates. Old dismissals are cleaned up on app launch (remove entries for events no longer in calendar).

**Placement:** Appears in the Plan tab between the hero banner and the regular plan content, in the `.tripDetected` state.

### AgendaComposer Changes

**Approach: Adapter pattern.** Convert `POIResult` arrays into `Activity` and `LunchSpot` objects so the existing `compose()` signature and `parseSlots()` pipeline remain unchanged.

```swift
extension POIResult {
    func toActivity() -> Activity { ... }   // Maps category, name, coords, URL
    func toLunchSpot() -> LunchSpot { ... } // For .restaurant and .cafe categories
}
// Adapter defaults for Activity fields not available from MKLocalSearch:
// suggestibility = "always", recurring = nil, stayHome = false,
// ageRange = "0-99", duration = 60, price = nil, indoor = (heuristic by category),
// nameDE = name (no translation), descriptionDE = nil
// FreshnessScorer: bypass isFeedOnly, availableMonths, season checks for POI-sourced activities
```

**Additional changes:**
- Add trip context to the system prompt when in trip mode: "The user is visiting [locality] for [event]. Plan activities around the anchor event using nearby points of interest. These are real places found via Apple Maps — include their names exactly."
- Activity adapter sets `indoor` based on category heuristic (museum/cafe → indoor, playground/park/lake → outdoor)
- FreshnessScorer uses `POIResult.id` (the `name-lat3-lon3` key) for deduplication

### Fallback (No API Key / Network Error)

If Claude API is unavailable, instead of TemplateEngine (which expects curated data), use a **simple distance-based fallback**:

1. Sort POI pool by category priority (playground > park > museum > restaurant > cafe > bakery > lake)
2. For each gap, pick the nearest unfilled POI matching the gap type (activity gaps → playground/park/museum, lunch/dinner gaps → restaurant/cafe)
3. Build `DayAgenda` with generic reasoning text ("Nearby playground, 5 min walk")

This avoids adapting TemplateEngine's archetype system for arbitrary POI data.

### PlanViewModel Changes

- New state: `.tripDetected(DetectedTrip)` — shown when away-event found, before composing
- `dealTrip(_ trip: DetectedTrip)` method:
  1. Set state to `.composing`
  2. Call `POISearchService.search(near: trip.coordinate)`
  3. Fetch weather for `trip.coordinate`
  4. Run `GapAnalysisEngine.analyse()` with trip event as anchor
  5. Convert POIs via adapter, call `AgendaComposer.compose()`
  6. Set state to `.dealt(agenda)`
- Hero banner adapts: "Your day in [locality]" instead of "Plan your [weekday]"
- PlanStore key: `"trip-\(locality.lowercased())"` as city component (prefixed to avoid collision with curated city IDs like "zurich")

## Not in Scope

- Manual destination search UI (calendar is the entry point)
- Multi-day trip planning (one day at a time)
- Hotel/accommodation search
- Transit routing to the destination (just planning once there)
- Photo fetching for arbitrary POIs (gradient + icon fallback)
- New backend/worker endpoints (all client-side)
- Overpass API integration (MKLocalSearch is sufficient for v1)

## Edge Cases

- **No calendar events with locations**: No nudge shown, Plan tab works as normal for home city
- **Multiple away-events in different localities on same day**: V1 shows nudge for the chronologically first away-event in a non-curated locality. Events in curated cities (the 7) are handled by the existing flow.
- **Away-event in one of the 7 supported cities**: TripDetector checks `City.allCases` — if the locality matches a curated city, skip it. The existing plan flow with Worker API data handles these (better quality).
- **MKLocalSearch returns few results**: Widen search radius progressively (5km → 10km → 15km). If still sparse, composer works with what's available.
- **No internet for MKLocalSearch**: MKLocalSearch requires network. Show error state with retry button.
- **Calendar permission denied**: TripDetector requires same calendar access already granted for the regular Plan tab. No new permission needed.
- **Reverse geocoding rate limits**: Serial execution with 1s delay. Cache aggressively by rounded coordinate.
- **Date switch latency**: TripDetector involves async geocoding. To avoid latency on every date tap, prefetch trip detection for the visible date strip range (7-14 days) on initial Plan tab load, cache results in memory.
- **Locality name edge cases**: Distance check (>5km) as fallback prevents false positives for suburbs that geocode to a different locality name but are functionally local.
- **Redeal spam / MKLocalSearch throttling**: POI results cached for 1 hour per coordinate+radius. Redeal reuses cached POIs, only re-runs the composer.
