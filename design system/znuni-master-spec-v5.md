# Znüni — Today Tab, Agenda Composer & Freshness System
## Master Implementation Brief v5.0 — Final

> **This document supersedes all previous briefs.**
> All open questions resolved. Ready for implementation.
> Last updated: March 2026

---

## 1. CONTEXT & ARCHITECTURE OVERVIEW

Znüni is a SwiftUI iOS app for Zürich families. Five tabs: Today, Activities, Explore, Weekend, Settings.

**Design tokens — do not deviate:**
- Navy `#1A3A5C` · Terracotta `#C4623A` · Cream `#F5F0E8` · Surface `#FAF8F4`
- Border `#E8E0D0` · Ink `#1C1A16` · Muted `#8A8070`
- Positive `#3A7D5C` · Negative `#B04040` · Exec `#0F2238`
- Fonts: Playfair Display (headers/titles) · DM Sans (all body/UI)

**Three data sources feed the planner:**
1. **Personal anchors** — manually entered by user (birthday party, football training)
2. **Znüni curated data** — Cloudflare KV/Worker (CityEvents, Activities, Restaurants)
3. **AI venue selection** — Claude picks from a pre-scored, pre-filtered pool

**Core architectural principle:**
Layout decisions (slot count, slot times, slot types) are made deterministically in Swift by `GapAnalysisEngine` before any API call. Claude's only job is venue selection from a pre-qualified pool. Claude never decides slot count, timing, or type.

**Resolved architecture decisions:**
- Storage: Cloudflare KV (not D1). Keys prefixed with `profileId`.
- Single user: `profileId = "bisho"` hardcoded. Multi-profile added later via auth only — no schema changes needed.
- Opening hours: unstructured display strings on activities; raw OSM strings on restaurants. Structured parsing not available — use `isLikelyOpen()` heuristic from existing worker code.
- Neighbourhood/kreis: not stored on venue records. Derive at runtime from `lat`/`lon` via existing `ZurichKreis.swift`.
- Calendar-to-anchor: label pre-fill only. No time/duration data on CityEvents. User always picks time and duration manually.
- Weather for multi-day: `fetchWeekendWeather()` already returns 7-day daily forecast. Use it directly.
- Recurring activities (farmers market, story time): identified by presence of `recurring` string field on Activity. These are feed-only — never enter the planning pool.
- CityEvents: plannable by default. Add `plannable: Bool` field to `events.js` for any exceptions.

---

## 2. EXISTING DATA MODELS — ACTUAL FIELDS

### 2a. Activity (from activities.js / ACTIVITIES_KV)

```typescript
// Actual existing schema — do not assume any other fields
{
  id: string               // "zoo-zurich"
  name: string             // "Zoo Zürich"
  nameDE: string           // "Zoo Zürich"
  lat: number              // 47.3849
  lon: number              // 8.5743
  openingHours: string     // "Daily 9:00–17:00"  ← display string, not structured
  openingHoursDE: string
  indoor: boolean          // false
  category: string         // "animals" | "museum" | "playground" | ...
  duration: string         // "2-4 hours"  ← display string, not structured
  price: string            // "CHF 29 adults, kids under 6 free"
  priceDE: string
  recurring?: string       // "Tue & Fri 6:00–11:00"  ← presence = feed-only
  season?: string          // "winter"
  availableMonths?: number[] // [11, 12]
}
```

**Missing fields needed by the planner — must be added to activities.js:**
```typescript
suggestibility?: 'free' | 'seasonal' | 'feedOnly' | 'oncePer30Days'
// Default if absent: 'free' (except when recurring is present → 'feedOnly')
```

No `ageMin`/`ageMax`, no `kreis`, no structured hours, no `priceRange`. Age filtering deferred to Claude prompt. Kreis derived from lat/lon at runtime.

### 2b. Restaurant (from lunch.js / Overpass OSM)

```typescript
// Actual existing schema
{
  id: string               // "osm-1234567"
  name: string             // "Frau Gerolds Garten"
  lat: number              // 47.3876
  lon: number              // 8.5280
  openingHours: string     // raw OSM string e.g. "Mo-Su 11:00-23:00; Tu off"
  openForLunch: boolean    // computed: parsed from hours, 11:00–14:00 window
  amenity: string          // "restaurant" | "cafe" | "fast_food"
  cuisine: string          // "italian;pizza"
  cuisineCategory: string  // "italian"
  rating: number           // 4.5
  ratingCount: number      // 1234
}
```

**Missing fields needed — must be added to lunch.js enrichment:**
```typescript
openForDinner?: boolean    // computed: parsed from hours, 17:00–21:00 window
kidFriendly?: boolean      // manual curation or heuristic (cafe + high rating + family area)
suggestibility?: 'free' | 'feedOnly' | 'oncePer30Days'
// Default if absent: 'free'
```

### 2c. CityEvent (from events.js)

```typescript
// Actual existing schema
{
  id: string               // "zh-sechselaeuten"
  name: string             // "Sechseläuten"
  city: string             // "zurich"
  startDate: string        // "2026-04-20"  ← date only, no time
  endDate: string          // "2026-04-20"  ← date only, no time
  toddlerFriendly: boolean
  free: boolean
  url: string
}
```

**Missing fields needed — add to events.js:**
```typescript
plannable: boolean         // true = can become an anchor; false = informational only
// Default: true for all existing events unless overridden
// Set false for: school holiday blocks, public holiday markers (not events you "attend")
```

No `startTime`, no `durationMinutes`, no `lat`/`lon` on events. This is permanent — calendar-to-anchor always requires manual time/duration input from the user.

### 2d. Photo access

Photos are not a field on any model. Access via:
```
GET /photo/{venueId}
```
Worker fetches from R2 bucket `swiss-news-images` at key `photos/{id}`.
For restaurants without a curated ID, worker accepts query params: `?name=...&lat=...&lon=...`
Use `AsyncImage` with the predictable URL. No changes needed.

---

## 3. NEW DATA MODELS

### 3a. AnchorEvent

```swift
enum AnchorCategory: String, Codable, CaseIterable {
    case food       // restaurant, brunch, café → suppresses adjacent food slots
    case social     // birthday party, playdate → suppresses adjacent activity slots
    case activity   // sport, class, museum → suppresses adjacent activity slots
    case errand     // shopping, appointment → no suppression
    case other      // → no suppression

    var emoji: String {
        switch self {
        case .food:     return "🍴"
        case .social:   return "🎉"
        case .activity: return "🏃"
        case .errand:   return "🛒"
        case .other:    return "📌"
        }
    }
}

struct AnchorEvent: Codable, Identifiable {
    let id: UUID
    var title: String
    var category: AnchorCategory        // REQUIRED
    var startTime: Date
    var durationMinutes: Int            // REQUIRED — always ask user
    var neighbourhood: String?          // user-entered or derived
    var kreis: Int?                     // derived from lat/lon if venue is a CityEvent
    var sourceEventId: String?          // set when anchor came from a CityEvent
    let createdDate: Date

    var endTime: Date {
        startTime.addingTimeInterval(Double(durationMinutes) * 60)
    }

    var promptDescription: String {
        var parts = [
            "\"\(title)\"",
            "category: \(category.rawValue)",
            "starts: \(startTime.formatted(.dateTime.hour().minute()))",
            "ends: \(endTime.formatted(.dateTime.hour().minute()))"
        ]
        if let n = neighbourhood { parts.append("location: \(n)") }
        return parts.joined(separator: ", ")
    }

    func toAgendaSlot() -> AgendaSlot {
        AgendaSlot(
            id: id.uuidString,
            source: .userAnchor,
            suggestionType: nil,
            slotDate: startTime,
            durationMinutes: durationMinutes,
            venueName: title,
            venueId: nil,
            neighbourhood: neighbourhood,
            reason: "",
            travelMinutesToNext: nil,
            swaps: [],
            isLocked: true,
            anchorCategory: category,
            anchorEndTime: endTime
        )
    }
}

class AnchorStore {
    // Today's anchors: UserDefaults, purged at midnight
    func anchors(for date: Date) -> [AnchorEvent]
    func add(_ anchor: AnchorEvent)
    func update(_ anchor: AnchorEvent)
    func remove(id: UUID)
    func purgeIfNewDay()                // call on app foreground

    // Future anchors (for multi-day planning): synced to KV
    func syncFutureAnchors() async      // GET /api/anchors?from=today&to=+14days
    func storeFutureAnchor(_ anchor: AnchorEvent) async  // PUT /api/anchors/{id}
    func deleteFutureAnchor(id: UUID) async              // DELETE /api/anchors/{id}
}
```

### 3b. VenueVisit

```swift
struct VenueVisit: Codable, Identifiable {
    let id: UUID
    let profileId: String               // "bisho" — multi-profile ready
    let venueId: String
    let venueName: String
    let venueType: VenueType
    let visitDate: Date
    let source: VisitSource
    let weatherCondition: String?
    let familySnapshot: String          // "Sami(3)" — for future analytics
}

enum VenueType: String, Codable {
    case activity
    case restaurant
    case curatedEvent
}

enum VisitSource: String, Codable {
    case executionCheckIn   // "Done ✓" tap — confirmed visit, full weight
    case manualMark         // "We've been here" button — confirmed, full weight
    case planCompletion     // reached end of execution — assumed, 50% weight
}

class VenueVisitStore {
    let profileId = "bisho"

    // Local (UserDefaults) — always written first
    func record(_ visit: VenueVisit)
    func lastVisit(for venueId: String) -> VenueVisit?
    func daysSinceLastVisit(for venueId: String) -> Int?   // nil = never
    func visitCount(for venueId: String, inLast days: Int) -> Int

    // KV sync — opportunistic, non-blocking
    func syncToKV() async       // POST /api/visits
    func syncFromKV() async     // GET /api/visits?since=90daysAgo
}
```

### 3c. FreshnessScorer

```swift
struct VenueScore {
    let venueId: String
    let isEligible: Bool            // false = hard excluded, never shown to Claude
    let compositeScore: Double      // 0.0–1.0, only meaningful when isEligible = true
}

struct FreshnessScorer {

    static func scoreActivity(
        _ activity: Activity,
        visitStore: VenueVisitStore,
        weather: WeatherData,
        date: Date
    ) -> VenueScore {

        // ── Hard exclusions ──────────────────────────────────
        
        // 1. Feed-only: recurring activities never enter planning pool
        if activity.recurring != nil { return ineligible(activity.id) }
        if activity.suggestibility == "feedOnly" { return ineligible(activity.id) }

        // 2. Seasonal: only suggest in available months
        if let months = activity.availableMonths {
            let month = Calendar.current.component(.month, from: date)
            if !months.contains(month) { return ineligible(activity.id) }
        }

        // 3. Visit recency
        let exclusionDays = activity.suggestibility == "oncePer30Days" ? 30 : 14
        if let days = visitStore.daysSinceLastVisit(for: activity.id), days < exclusionDays {
            return ineligible(activity.id)
        }

        // ── Soft scoring ──────────────────────────────────────

        let freshness = freshnessScore(
            venueId: activity.id, visitStore: visitStore, exclusionDays: exclusionDays)

        let weather: Double
        if activity.indoor {
            weather = 1.0
        } else {
            weather = outdoorWeatherScore(weather)
        }

        let seasonal = activity.availableMonths == nil ? 0.85 : 1.0

        let recentCount = visitStore.visitCount(for: activity.id, inLast: 30)
        let variety = max(0.0, 1.0 - Double(recentCount) * 0.25)

        let composite = (freshness * 0.35) + (weather * 0.30)
                      + (seasonal * 0.20) + (variety  * 0.15)

        return VenueScore(venueId: activity.id, isEligible: true, compositeScore: composite)
    }

    static func scoreRestaurant(
        _ restaurant: Restaurant,
        slotType: SuggestionType,           // .lunch or .dinner
        visitStore: VenueVisitStore,
        weather: WeatherData,
        date: Date
    ) -> VenueScore {

        // 1. Feed-only
        if restaurant.suggestibility == "feedOnly" { return ineligible(restaurant.id) }

        // 2. Slot type eligibility
        switch slotType {
        case .lunch:
            if !restaurant.openForLunch { return ineligible(restaurant.id) }
        case .dinner:
            guard restaurant.openForDinner == true else { return ineligible(restaurant.id) }
        default:
            return ineligible(restaurant.id)
        }

        // 3. Visit recency (restaurants: 14-day default)
        let exclusionDays = restaurant.suggestibility == "oncePer30Days" ? 30 : 14
        if let days = visitStore.daysSinceLastVisit(for: restaurant.id), days < exclusionDays {
            return ineligible(restaurant.id)
        }

        let freshness = freshnessScore(
            venueId: restaurant.id, visitStore: visitStore, exclusionDays: exclusionDays)
        let recentCount = visitStore.visitCount(for: restaurant.id, inLast: 30)
        let variety = max(0.0, 1.0 - Double(recentCount) * 0.25)
        let composite = (freshness * 0.50) + (variety * 0.50)

        return VenueScore(venueId: restaurant.id, isEligible: true, compositeScore: composite)
    }

    // ── Helpers ──────────────────────────────────────────────

    private static func freshnessScore(
        venueId: String, visitStore: VenueVisitStore, exclusionDays: Int
    ) -> Double {
        guard let days = visitStore.daysSinceLastVisit(for: venueId) else { return 1.0 }
        return min(1.0, Double(days) / Double(exclusionDays * 2))
    }

    private static func outdoorWeatherScore(_ weather: WeatherData) -> Double {
        if weather.currentTemp < 8 || weather.isHeavyRain { return 0.1 }
        if weather.currentTemp < 14 || weather.isLightRain { return 0.5 }
        return 1.0
    }

    private static func ineligible(_ id: String) -> VenueScore {
        VenueScore(venueId: id, isEligible: false, compositeScore: 0)
    }
}
```

**Scoring pipeline — called before every AgendaComposer invocation:**
```swift
func buildScoredPool(
    activities: [Activity],
    restaurants: [Restaurant],
    weather: WeatherData,
    date: Date,
    fillableGaps: [FreeGap]
) -> (activities: [Activity], lunches: [Restaurant], dinners: [Restaurant]) {

    let needsDinner = fillableGaps.contains { $0.suggestedType == .dinner }
    let needsLunch  = fillableGaps.contains { $0.suggestedType == .lunch }

    let scoredActivities = activities
        .map { ($0, FreshnessScorer.scoreActivity($0, visitStore: visitStore, weather: weather, date: date)) }
        .filter { $0.1.isEligible }
        .sorted { $0.1.compositeScore > $1.1.compositeScore }
        .prefix(15)
        .map { $0.0 }

    let scoredLunches = needsLunch ? restaurants
        .map { ($0, FreshnessScorer.scoreRestaurant($0, slotType: .lunch, visitStore: visitStore, weather: weather, date: date)) }
        .filter { $0.1.isEligible }
        .sorted { $0.1.compositeScore > $1.1.compositeScore }
        .prefix(10)
        .map { $0.0 } : []

    let scoredDinners = needsDinner ? restaurants
        .map { ($0, FreshnessScorer.scoreRestaurant($0, slotType: .dinner, visitStore: visitStore, weather: weather, date: date)) }
        .filter { $0.1.isEligible }
        .sorted { $0.1.compositeScore > $1.1.compositeScore }
        .prefix(10)
        .map { $0.0 } : []

    return (Array(scoredActivities), Array(scoredLunches), Array(scoredDinners))
}
```

### 3d. GapAnalysisEngine

```swift
enum SuggestionType: String, Codable {
    case morningActivity
    case lunch
    case afternoonActivity
    case dinner
    case quickActivity
}

struct FreeGap: Identifiable {
    let id: UUID
    let gapStart: Date
    let gapEnd: Date
    let effectiveStart: Date        // max(gapStart, now + 15min)
    let effectiveMinutes: Int
    let precedingAnchor: AnchorEvent?
    let followingAnchor: AnchorEvent?
    let suggestedType: SuggestionType?
    let isFillable: Bool
}

struct GapAnalysisEngine {
    static let dayStartHour = 8
    static let dayEndHour   = 21
    static let minFillableMinutes = 45

    static func analyse(anchors: [AnchorEvent], now: Date, date: Date) -> [FreeGap] {
        let cal      = Calendar.current
        let dayStart = cal.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: date)!
        let dayEnd   = cal.date(bySettingHour: dayEndHour,   minute: 0, second: 0, of: date)!
        let sorted   = anchors.sorted { $0.startTime < $1.startTime }

        var segments: [(start: Date, end: Date, before: AnchorEvent?, after: AnchorEvent?)] = []
        var cursor = dayStart

        for (i, anchor) in sorted.enumerated() {
            if anchor.startTime > cursor {
                segments.append((cursor, anchor.startTime,
                                 i > 0 ? sorted[i-1] : nil, anchor))
            }
            cursor = anchor.endTime
        }
        if cursor < dayEnd { segments.append((cursor, dayEnd, sorted.last, nil)) }

        return segments.map { seg in
            let effStart   = max(seg.start, now.addingTimeInterval(15 * 60))
            let effMinutes = max(0, Int(seg.end.timeIntervalSince(effStart) / 60))
            let fillable   = effMinutes >= minFillableMinutes
            let type       = fillable ? classifyGap(effStart, seg.end, seg.before, seg.after) : nil
            return FreeGap(id: UUID(), gapStart: seg.start, gapEnd: seg.end,
                           effectiveStart: effStart, effectiveMinutes: effMinutes,
                           precedingAnchor: seg.before, followingAnchor: seg.after,
                           suggestedType: type, isFillable: fillable && type != nil)
        }
    }

    private static func classifyGap(_ effStart: Date, _ end: Date,
                                     _ pre: AnchorEvent?, _ fol: AnchorEvent?) -> SuggestionType? {
        let suppressed = suppressedTypes(pre, fol)
        let effMins    = Int(end.timeIntervalSince(effStart) / 60)
        let startHour  = hour(effStart)
        let midHour    = hour(effStart.addingTimeInterval(end.timeIntervalSince(effStart) / 2))
        let endHour    = hour(end)

        if startHour >= 17 && effMins >= 60 && !suppressed.contains(.dinner)             { return .dinner }
        if midHour >= 11 && midHour <= 14 && effMins >= 45 && !suppressed.contains(.lunch) { return .lunch }
        if endHour <= 13 && !suppressed.contains(.morningActivity)                        { return .morningActivity }
        if startHour >= 13 && startHour < 18 && !suppressed.contains(.afternoonActivity) { return .afternoonActivity }
        if effMins >= 45 && !suppressed.contains(.quickActivity)                          { return .quickActivity }
        return nil
    }

    private static func suppressedTypes(_ pre: AnchorEvent?, _ fol: AnchorEvent?) -> Set<SuggestionType> {
        var s = Set<SuggestionType>()
        if let pre = pre {
            let h = hour(pre.endTime)
            switch pre.category {
            case .food:     if h >= 10 && h <= 15 { s.insert(.lunch) }
                            if h >= 17             { s.insert(.dinner) }
            case .activity: s.insert(.morningActivity); s.insert(.afternoonActivity)
            case .social:   s.insert(.afternoonActivity)
            default: break
            }
        }
        if let fol = fol {
            let h = hour(fol.startTime)
            switch fol.category {
            case .food: if h >= 11 && h <= 14 { s.insert(.lunch) }
                        if h >= 17             { s.insert(.dinner) }
            default: break
            }
        }
        return s
    }

    private static func hour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }
}
```

**Required unit tests — all must pass before UI work:**

| # | Anchors | now | Expected fillable gap types |
|---|---|---|---|
| 1 | None | 09:00 | morningActivity, lunch, afternoonActivity, dinner |
| 2 | None | 13:43 | afternoonActivity, dinner |
| 3 | Brunch 11:15–12:45 (food) + Party 14:00–17:00 (social) | 13:43 | dinner only |
| 4 | Dinner anchor 19:00–21:00 (food) | 09:00 | morningActivity, lunch, afternoonActivity |
| 5 | Anchors covering 08:00–21:00 | any | [] empty |
| 6 | None | 20:30 | [] empty |

### 3e. AgendaSlot

```swift
struct AgendaSlot: Codable, Identifiable {
    let id: String
    let source: SlotSource
    let suggestionType: SuggestionType?
    var slotDate: Date                      // always Date, never String
    var durationMinutes: Int?
    var venueName: String
    var venueId: String?
    var neighbourhood: String?
    var reason: String
    var travelMinutesToNext: Int?
    var swaps: [SwapOption]
    var isLocked: Bool
    var customVenueName: String?
    var customNeighbourhood: String?
    var checkInTime: Date?
    var checkOutTime: Date?
    var wasAutoCheckedIn: Bool
    var isStale: Bool
    var anchorCategory: AnchorCategory?    // anchor slots only
    var anchorEndTime: Date?               // anchor slots only

    var timeDisplay: String {
        slotDate.formatted(.dateTime.hour().minute())
    }
    var estimatedEndDate: Date? {
        durationMinutes.map { slotDate.addingTimeInterval(Double($0) * 60) }
    }
}

enum SlotSource: String, Codable {
    case aiGenerated
    case userCustom
    case userSwapped
    case userAnchor
}

struct SwapOption: Codable, Identifiable {
    let id: String
    let venueName: String
    let detail: String
}
```

### 3f. DayAgenda

```swift
struct DayAgenda: Codable {
    let date: Date
    let sessionSnapshot: FamilySession
    let theme: String
    let weatherNote: String
    let badWeatherMode: Bool
    var slots: [AgendaSlot]         // anchor + AI slots merged, sorted by slotDate
    let homeActivities: HomeActivities?

    func with(slots: [AgendaSlot]) -> DayAgenda {
        var copy = self; copy.slots = slots; return copy
    }
}
```

### 3g. Multi-day models

```swift
struct DayPlan: Codable, Identifiable {
    let id: UUID
    let date: Date
    var anchors: [AnchorEvent]
    var agenda: DayAgenda?
    var isComposed: Bool { agenda != nil }
}

struct MultiDayPlan: Codable, Identifiable {
    let id: UUID
    let title: String
    var days: [DayPlan]
    let createdAt: Date
}

class MultiDayPlanStore {
    func store(_ plan: MultiDayPlan)
    func plan(for id: UUID) -> MultiDayPlan?
    func allPlans() -> [MultiDayPlan]
    func delete(id: UUID)
    func purgeOlderThan(days: Int)
}
```

### 3h. Carry forward unchanged from v2

- `FamilySession` + `FamilySession.Child`
- `HomeActivities` (baking, movie, craft)
- `RecentlyShownStore`
- `AgendaCache` (cache key updated — see §4b)
- `CheckInRecord` + `CheckInStore`
- `TimelineShifter`
- `FeasibilityChecker` + `FeasibilityWarning`
- `GeofenceMonitor`
- `AgendaNotificationScheduler`
- `AgendaMode` enum
- `TodaySubView` enum

---

## 4. AGENDA COMPOSER

### 4a. Full composition flow

```
App foreground
    ↓
AnchorStore.purgeIfNewDay()
VenueVisitStore.syncFromKV()          ← non-blocking, fires in background
    ↓
TodayView appears
    ↓
Check AgendaCache (key = date + sessionHash + anchorsHash)
    ↓ cache miss
GapAnalysisEngine.analyse(anchors, now, date) → [FreeGap]
    ↓
Zero fillable gaps?
    → Show anchor-only or DayComplete view (no API call)
    ↓
buildScoredPool(activities, restaurants, weather, date, fillableGaps)
    ↓
Build prompt with scored pool + fillable gaps
    ↓
POST to Anthropic API
    ↓
Parse [AgendaSlot] from response
    ↓
anchors.map { $0.toAgendaSlot() }     ← in Swift, not by Claude
    ↓
Merge + sort by slotDate → DayAgenda.slots
    ↓
Store in AgendaCache
    ↓ parallel
API failure / timeout >5s → TemplateEngine fallback
```

### 4b. Cache key

```swift
struct AgendaCacheKey: Hashable {
    let date: String            // "2026-03-15"
    let sessionHash: Int
    let anchorsHash: Int        // sorted anchor ids + startTimes, hashed
}
```

### 4c. System prompt

```
You are a family day planner for Zürich, Switzerland.

You will receive a list of pre-analysed time gaps and a pre-scored, pre-filtered list of venues.
Your only job: assign the best venue to each gap.

RULES:
1. Only use venues from the provided lists. Never invent venues.
2. Match gap type exactly: lunch gaps → restaurants, activity gaps → activities.
3. Age-appropriate choices only. Children's ages are provided.
4. Geographic coherence: consecutive slots should be in the same or adjacent Kreis where possible.
5. Never repeat a venueId that appears in recentlyShownIds.
6. "reason": 1–2 sentences specific to this family, this weather, and this gap's position in the day.
7. Each slot: 2–3 swap alternatives from the same type pool.
8. travelMinutesToNext: estimate based on neighbourhood proximity to next slot or anchor.
9. Bad weather mode: indoor venues only.
10. Do not reference, output, or acknowledge anchor events — handled separately in Swift.
11. Return ONLY a JSON array. No explanation, no markdown, no preamble.
```

### 4d. User prompt

```swift
func buildPrompt(
    gaps: [FreeGap],
    activities: [Activity],
    lunches: [Restaurant],
    dinners: [Restaurant],
    weather: WeatherData,
    session: FamilySession,
    anchors: [AnchorEvent],
    recentlyShown: [String],
    homeKreis: Int,
    now: Date,
    date: Date,
    badWeatherMode: Bool
) -> String {
    let gapLines = gaps.enumerated().map { i, g in
        "Gap \(i+1): type=\(g.suggestedType!.rawValue), from=\(fmt(g.effectiveStart)), to=\(fmt(g.gapEnd)), \(g.effectiveMinutes)min"
    }.joined(separator: "\n")

    let activityLines = activities.map { a in
        "[\(a.id)] \(a.name) | \(a.indoor ? "indoor" : "outdoor") | \(a.category) | \(a.openingHours) | \(a.price)"
    }.joined(separator: "\n")

    let lunchLines = lunches.map { r in
        "[\(r.id)] \(r.name) | \(r.cuisineCategory) | rating:\(r.rating) | \(r.openingHours)"
    }.joined(separator: "\n")

    let dinnerLines = dinners.map { r in
        "[\(r.id)] \(r.name) | \(r.cuisineCategory) | rating:\(r.rating) | \(r.openingHours)"
    }.joined(separator: "\n")

    return """
    Date: \(fmtDate(date))
    Now: \(fmt(now))
    Weather: \(weather.condition), \(weather.currentTemp)°C
    Bad weather mode: \(badWeatherMode)
    Family: \(session.description)
    Home Kreis: \(homeKreis)

    \(anchors.isEmpty ? "" : "Commitments today (context only — do not output):\n\(anchors.map { $0.promptDescription }.joined(separator: "\n"))\n")
    Gaps to fill:
    \(gapLines)

    Do not suggest: \(recentlyShown.joined(separator: ", "))

    Activities:
    \(activityLines)

    Lunch restaurants:
    \(lunchLines)

    Dinner restaurants:
    \(dinnerLines)

    Return JSON array of exactly \(gaps.count) objects:
    [{"gapIndex":0,"venueId":"...","venueName":"...","slotTime":"HH:MM","reason":"...","travelMinutesToNext":null,"swaps":[{"id":"...","venueName":"...","detail":"..."}]}]
    """
}
```

### 4e. Response parsing

```swift
func parseResponse(_ items: [[String: Any]], gaps: [FreeGap], date: Date) -> [AgendaSlot] {
    items.compactMap { item in
        guard let idx = item["gapIndex"] as? Int, idx < gaps.count,
              let name = item["venueName"] as? String,
              let timeStr = item["slotTime"] as? String else { return nil }
        let gap = gaps[idx]
        let slotDate = parseHHMM(timeStr, on: date) ?? gap.effectiveStart
        let swaps = parseSwaps(item["swaps"])
        return AgendaSlot(
            id: UUID().uuidString, source: .aiGenerated,
            suggestionType: gap.suggestedType, slotDate: slotDate,
            durationMinutes: nil, venueName: name,
            venueId: item["venueId"] as? String, neighbourhood: nil,
            reason: (item["reason"] as? String) ?? "",
            travelMinutesToNext: item["travelMinutesToNext"] as? Int,
            swaps: swaps, isLocked: false,
            wasAutoCheckedIn: false, isStale: false
        )
    }
}
```

---

## 5. VISIT TRACKING

### 5a. When visits are recorded

**executionCheckIn** — user taps "Done ✓" on active slot in execution mode:
```swift
func handleCheckIn(slot: AgendaSlot) {
    if let venueId = slot.venueId {
        visitStore.record(VenueVisit(
            id: UUID(), profileId: "bisho",
            venueId: venueId, venueName: slot.venueName,
            venueType: slot.suggestionType == .lunch || slot.suggestionType == .dinner
                ? .restaurant : .activity,
            visitDate: Date(), source: .executionCheckIn,
            weatherCondition: currentWeather?.condition,
            familySnapshot: familySession.snapshotString
        ))
        Task { await visitStore.syncToKV() }
    }
    // existing timeline shift logic continues unchanged
}
```

**manualMark** — "We've been here" button on expanded activity/restaurant cards:
- Add to: `ActivityCardExpanded`, `LunchCard expanded state`
- Button label: "📍 Mark as visited"
- Tap: shows inline date picker defaulting to today
- Confirm: records visit, shows "✓ Marked" for 2 seconds

**planCompletion** — user reaches final slot in execution mode:
- Record any unconfirmed slots with `source: .planCompletion`
- These are excluded from the 14-day hard exclusion window but reduce variety score

### 5b. KV storage schema

```
Key: visits:bisho:{venueId}
Value: JSON array of last 10 visits (trim oldest on write)
[{ id, visitDate, source, weatherCondition, familySnapshot }]

Key: plans:bisho:{date}           e.g. "plans:bisho:2026-03-15"
Value: DayAgenda serialised as JSON

Key: anchors:bisho:{date}         e.g. "anchors:bisho:2026-03-22"
Value: [AnchorEvent] JSON array (future-dated only)
```

### 5c. Worker API endpoints

Add to existing Cloudflare Worker:

```typescript
// GET /api/visits?since=2026-01-15&profileId=bisho
// Returns all visit keys matching prefix visits:bisho:*
// Filters to visits since the given date

// POST /api/visits
// Body: VenueVisit JSON
// KV.put(`visits:${profileId}:${venueId}`, updatedArray)

// GET /api/anchors?from=2026-03-15&to=2026-03-29&profileId=bisho
// Lists keys anchors:bisho:* in date range, returns merged array

// PUT /api/anchors/:id
// Body: AnchorEvent JSON — finds correct date key, upserts

// DELETE /api/anchors/:id
// Removes anchor from its date key

// GET /api/plans?profileId=bisho&limit=30
// POST /api/plans
// Body: { profileId, planDate, agendaJson }
```

All endpoints require header: `X-Znuni-Key: {secret}`

Offline behaviour: all writes go to UserDefaults first. KV sync fires in background. If sync fails, retries on next foreground. UI never blocks on network.

---

## 6. CURATED EVENTS → ANCHOR FLOW

### 6a. What changes in events.js

Add one field to each CityEvent record:

```typescript
plannable: boolean   // default: true
// Set false for: school holiday date ranges, public holiday markers
// These show in the calendar as context but are not things you "attend"
// Example: plannable: false for "Sommerferien 2026"
// Example: plannable: true for "Sechseläuten", "Zürich Marathon"
```

### 6b. "Add to plan" CTA

On CityEvent detail sheet (Explore tab), when `event.plannable === true`:

```
[ 🗓 Add to your plan for [day name] ]
```

Tap opens `AnchorFormSheet` with:
- **Title pre-filled**: `event.name`
- **Category pre-selected**: mapped from event type (see below)
- **Time**: user picks — no data to pre-fill
- **Duration**: user picks — no data to pre-fill
- **Where**: user picks — no lat/lon on events

```swift
extension CityEvent {
    var defaultAnchorCategory: AnchorCategory {
        // Map based on known event characteristics
        // Can be refined per-event via a lookup table
        switch self.id {
        case let id where id.contains("markt"):   return .food
        case let id where id.contains("marathon"): return .activity
        case let id where id.contains("festival"): return .social
        default: return .activity
        }
    }
}
```

`sourceEventId` is set on the created `AnchorEvent` to link back to the originating event.

### 6c. Recurring activities in the calendar

Activities with a `recurring` field appear in the calendar via `isAvailable(on:)`. No "Add to plan" CTA on these — they are feed-only. The calendar shows them as informational dots only.

---

## 7. TODAY SCREEN STRUCTURE

```
TodayView
├── TodayHeaderView
│   ├── Status bar
│   ├── Eyebrow (date)
│   ├── Title + SegmentControl (Plan / News)
│   ├── [browsing]   WeatherRow + SessionPill + AnchorPillRow + ContextBanner
│   ├── [executing]  ProgressDots + CurrentSlotHero + UpNextStrip
│   └── [news]       NewsCount + CategoryFilters
│
├── [subView == .plan]
│   └── ScrollView
│       ├── TransportAlertView (conditional)
│       ├── AgendaView
│       │   ├── AgendaLoadingView         (composing)
│       │   ├── AgendaTimelineView        (≥1 fillable gap, good weather)
│       │   ├── BadWeatherAgendaView      (bad weather mode)
│       │   ├── AnchorOnlyView            (anchors exist, no fillable gaps)
│       │   └── DayCompleteView           (all elapsed, no future anchors)
│       └── LetGoButton / EditPlanLink
│
└── [subView == .news]
    └── ScrollView
        ├── TransportAlertView
        ├── ThisDayInHistoryView
        └── NewsFeedView
```

---

## 8. HEADER

### Weather variants
- Good weather: Navy `#1A3A5C` background
- Bad weather (temp < 10° AND heavy rain/snow): `#2C2018` background, warm amber text

### AnchorFormSheet — 5 steps

1. **What** — free text, placeholder "Birthday party, football training…"
2. **What kind** — 2×2 grid: 🍴 Food & Drink / 🎉 Social / 🏃 Activity / 📌 Other. **Required.**
3. **When** — time picker, defaults to nearest half-hour from now
4. **How long** — segmented: 30 min / 1 hr / 1.5 hr / 2 hr / 3 hr / Custom. **Required.**
5. **Where** — neighbourhood chips, optional

Save button disabled until steps 2 and 4 complete.
Pre-fill from CityEvent: title (step 1) + category (step 2) pre-selected. Steps 3–4 always manual.

### Anchor pill display
```
[ 🍴 Brunch at Khouris · 11:15–12:45 · Seefeld  ✕ ]
[ 🎉 Noah's birthday · 14:00–16:00               ✕ ]
[ + Add another ]
```

### Context banner — gap-aware
```swift
var contextBannerText: String {
    if allGapsElapsed    { return "That's your day — enjoy your evening." }
    if !hasFillableGaps  { return "Your day is pretty full — enjoy what you have." }
    if isBadWeatherDay   { return "Cold and wet today — indoor suggestions only." }
    if fillableGaps.count == 1 {
        return "Most of today is covered — one \(fillableGaps[0].suggestedType!.rawValue) suggestion left."
    }
    return "Good day for getting out. Built a full day for \(session.childrenDisplay)."
}
```

---

## 9. TIMELINE VIEW

### Unified rendering
`AgendaTimelineView` renders `DayAgenda.slots` — anchor and AI slots already merged and sorted. No special insertion logic.

### Anchor slot card
```
Background:  rgba(26,58,92, 0.04)
Border:      1.5px solid rgba(26,58,92, 0.18)
Left accent: 3px solid Navy
Dot:         Navy, no glow
Badge:       "[emoji] Your plans" — navy pill
Time:        "11:15 – 12:45" range display
Hidden:      reason, swap button, ··· menu
Tap:         expands → Edit / Remove only
Past:        45% opacity, "Done" label
```

### Special states
- **DayCompleteView**: "That's your day — enjoy your evening." No Let's go button.
- **AnchorOnlyView**: Future anchor cards only. No Let's go button. No AI suggestions.
- **Zero anchors, zero gaps (20:30+)**: DayCompleteView.

---

## 10. BAD WEATHER — unchanged from v2

---

## 11. MULTI-DAY PLANNING

Weekend tab gains "Plan the weekend →" button → `MultiDayPlannerView`.

### Composition
```swift
for (i, day) in multiDayPlan.days.enumerated() {
    // For today: use actual now. For future days: use 08:00 on that date.
    let now = Calendar.current.isDateInToday(day.date)
        ? Date()
        : Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: day.date)!

    // Weather: use fetchWeekendWeather() — 7-day forecast already available
    let weather = await weatherStore.forecast(for: day.date)

    let gaps  = GapAnalysisEngine.analyse(anchors: day.anchors, now: now, date: day.date)
    let pool  = buildScoredPool(activities, restaurants, weather, day.date, gaps.filter { $0.isFillable })
    let agenda = try? await AgendaComposer.shared.compose(gaps: gaps.filter { $0.isFillable },
                                                           pool: pool, weather: weather,
                                                           session: familySession,
                                                           anchors: day.anchors, date: day.date)
    if let agenda { multiDayPlan.days[i].agenda = agenda }
}

// Cross-day duplicate check — replace day 2 duplicate with first swap option
let allIds = multiDayPlan.days.flatMap { $0.agenda?.slots.compactMap { $0.venueId } ?? [] }
let dupes  = Dictionary(grouping: allIds) { $0 }.filter { $0.value.count > 1 }.keys
for id in dupes { replaceDuplicateOnDay2(venueId: id) }

// Store to KV
Task { await multiDayPlanStore.syncToKV(multiDayPlan) }
```

---

## 12. EXECUTION MODE — unchanged from v2 §11b

**One addition:** on final slot completion, record `planCompletion` visits for unchecked slots, then call `visitStore.syncToKV()`.

---

## 13. CUSTOM SLOTS & SLOT EDITING — unchanged from v2 §11c

---

## 14. CHECK-IN, TIMELINE SHIFT, NOTIFICATIONS — unchanged from v2 §11d

---

## 15. TEMPLATE ENGINE FALLBACK — unchanged from v2 §9

Apply `FreshnessScorer` to filter archetype pools before selection. If pool fully exhausted (all visited within exclusion window), reset rotation for that archetype only.

---

## 16. BUILD ORDER

Do in sequence. Each step independently testable. Do not skip.

**Step 1 — Schema additions (data + worker)**
- Add `suggestibility` field to `activities.js` records (default: `"free"`)
- Add `openForDinner` computed field to restaurant enrichment in `lunch.js`
- Add `plannable: true` to all `events.js` CityEvent records; set `false` for holiday blocks
- Add `kidFriendly` to restaurant records (manual curation pass — start with top 20 venues)
- No Swift changes in this step — this is worker/data work only

**Step 2 — Data models (Swift)**
- `AnchorCategory` enum
- `AnchorEvent` + `AnchorStore`
- `SuggestionType` enum + `FreeGap` struct
- `VenueVisit` + `VenueVisitStore` (local UserDefaults only — no KV yet)
- `VenueScore` + `FreshnessScorer`
- `AgendaSlot` revised (anchor fields, `slotDate` as Date, not String)
- `DayAgenda` revised
- `SlotSource` enum
- All carry-forward models from v2

**Step 3 — GapAnalysisEngine**
- Pure static functions, zero UI imports
- All 6 unit tests must pass before proceeding

**Step 4 — FreshnessScorer tests**
- Visited 3 days ago → ineligible (14-day window) ✓
- `recurring` field present → ineligible ✓
- Outdoor venue, temp 5°C → weatherScore 0.1 ✓
- `suggestibility = "feedOnly"` → ineligible ✓
- Never visited → freshnessScore 1.0 ✓

**Step 5 — Template engine fallback**
- Carry from v2, apply FreshnessScorer to archetype pools

**Step 6 — Today screen shell**
- Rename News → Today
- `TodaySubView`, `TodayView` structure
- Header: weather variants, segment control, session pill
- Gap-aware context banner
- News sub-view, transport alerts

**Step 7 — Revised AnchorFormSheet**
- 5-step form with CityEvent pre-fill support
- `AnchorPillRowView` showing time range

**Step 8 — Agenda UI**
- `AgendaLoadingView`
- `AgendaSlotCard` base
- `AnchorSlotCard`
- `LunchSlotCard` with "Suggest another nearby"
- `TravelConnectorView`
- `SwapTray`
- `AgendaTimelineView` unified
- `DayCompleteView`, `AnchorOnlyView`
- `BadWeatherAgendaView`

**Step 9 — API integration**
- `AgendaComposer` with gap-based prompt + scored pool
- `AnchorEvent.toAgendaSlot()` conversion
- Cache key with anchors hash
- Full wire-up: foreground → purge → score → gap analysis → compose → merge → display
- Error → TemplateEngine

**Step 10 — Visit tracking (local)**
- Wire "Done ✓" → `VenueVisitStore.record(executionCheckIn)`
- "We've been here" button on activity/restaurant cards
- Plan completion recording

**Step 11 — KV sync (Worker + iOS)**
- Add KV endpoints to Worker (`/api/visits`, `/api/plans`, `/api/anchors`)
- iOS sync: foreground pull, post-visit push
- Future anchor storage for multi-day

**Step 12 — Polish**
- Rebuild button
- Swap interactions + travel connector update on swap
- Session change → rebuild
- Anchor add/edit/remove → rebuild
- All special view states (complete, anchor-only, zero-gaps)

**Step 13 — Execution mode** — carry v2 + plan completion visit recording

**Step 14 — Custom slots + slot editing** — carry v2

**Step 15 — Check-in, timeline shift, notifications** — carry v2

**Step 16 — Multi-day planning**
- `DayPlan`, `MultiDayPlan`, `MultiDayPlanStore`
- `MultiDayPlannerView`
- Wire `fetchWeekendWeather()` forecast per day
- Cross-day duplicate check

**Step 17 — Calendar → anchor flow**
- "Add to plan" CTA on `plannable` CityEvents in Explore
- Pre-filled `AnchorFormSheet`
- `sourceEventId` linking

---

## 17. NOT IN THIS PASS

- Recurring anchors (weekly football training auto-population)
- Apple Calendar / Google Calendar import
- Server-side push notifications
- Adaptive timing learning from check-in deltas (`averageDelta` — stub only)
- Multi-profile / auth (profileId is hardcoded "bisho")
- Anchor suggestions or autocomplete on the text field
- Real-time venue open/closed via live API
- Geofence radius tuning per-venue (use 150m flat)
- Structured opening hours parsing (use `isLikelyOpen()` heuristic)

---

## 18. FILES

### New files
```
GapAnalysisEngine.swift
GapAnalysisEngineTests.swift
FreshnessScorer.swift
FreshnessScoreTests.swift
VenueVisit.swift
VenueVisitStore.swift
AnchorEvent.swift               ← replaces DayAnchor.swift
AnchorSlotCard.swift
DayCompleteView.swift
AnchorOnlyView.swift
MultiDayPlan.swift
MultiDayPlanStore.swift
MultiDayPlannerView.swift
```

### Modified files
```
activities.js                   ← add suggestibility field
lunch.js                        ← add openForDinner, kidFriendly
events.js                       ← add plannable field
worker/src/api.ts               ← add /api/visits, /api/plans, /api/anchors routes
Activity.swift                  ← add suggestibility, availableMonths (already exists), recurring
Restaurant.swift                ← add suggestibility, openForDinner, kidFriendly
CityEvent.swift                 ← add plannable field
AnchorFormSheet.swift           ← 5-step form, CityEvent pre-fill
AnchorPillRowView.swift         ← time range display
AgendaComposer.swift            ← gap-based prompt, scored pool input
AgendaCache.swift               ← anchors-aware cache key
AgendaTimelineView.swift        ← unified anchor+AI rendering
AgendaSlot.swift                ← anchor fields, Date not String
TodayView.swift                 ← gap-aware states, new view routing
ExploreCalendarView.swift       ← "Add to plan" CTA on plannable events
ActivityCard.swift              ← "We've been here" manual mark button
LunchCard.swift                 ← "We've been here" manual mark button
```

### Unchanged files
All other files from v2 carry forward without modification.
