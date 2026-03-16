# Znüni — App Rearchitecture Spec
## From Feature Tabs to User Flows
### v1.0 — March 2026

> **This document defines the restructuring of the existing Znüni app from 5 feature-organised tabs to 3 intent-organised tabs.**
> All existing features are retained. No features are removed — they are relocated and connected.
> This supersedes the tab structure defined in `znuni-master-spec-v5.md` §1 and §7.
> The planner engine (GapAnalysisEngine, FreshnessScorer, AgendaComposer, execution mode) is unchanged.

---

## 1. PROBLEM STATEMENT

The current app has five tabs (Today, Activities, Explore, Weekend, Settings) organised by feature type. Planning is fragmented across three tabs:

- **Today tab** → Plan sub-view → agenda for today/tomorrow only
- **Weekend tab** → Planner segment → agenda for Saturday/Sunday only
- **Explore tab** → Family Events → event browsing with "Add to plan" bridge to Today

These are the same planning engine (`GapAnalysisEngine` → `FreshnessScorer` → `AgendaComposer`) duplicated across two tabs with an awkward bridge from a third. Inspiration features (sunshine, snow, activities, events) are scattered without a clear path to action.

**The restructure organises the app around two user flows, not five feature buckets:**

- **Flow A — Plan a day:** "I know *when*, help me figure out *what*." Starts with a date. May have anchors or not. Output is a full agenda. (Scenarios 1, 2, 4, 5)
- **Flow B — Find a destination:** "I know I want *better weather*, help me figure out *where* and then *what*." Starts with a weather condition. Output is a place, which then feeds into Flow A. (Scenarios 3, 6)

Flow B always terminates in Flow A. The destination finder's job is done once the user picks a place.

---

## 2. USER SCENARIOS — PRIORITY RANKING

### Must nail (core product)

**Scenario 1 — Blank slate day.** It's Tuesday morning, kids are home, no plans. Decision paralysis. Open app → planner auto-generates a full-day agenda → browse/swap → "Let's go."

**Scenario 2 — Plan around a commitment.** Birthday party at 2pm. Morning and evening are wasted without a plan. Calendar sync imports event as anchor → planner fills gaps around it → slots near anchor are proximity-biased to anchor location.

**Scenario 3/6 — Escape the grey (sun or snow).** 3rd grey weekend. Where's the sun? Where's the snow? Destination finder → pick city/resort → see what's there → "Plan a day here" → planner builds agenda using that city's venue data.

### Strong but secondary

**Scenario 4 — City event.** Sechseläuten is April 20. Browse events → "Plan around this" → anchor form pre-filled → planner fills around event.

**Scenario 7 — What's happening.** FOMO. Browse events calendar → discover things → may or may not lead to planning.

### Deferred

**Scenario 5 — School holiday week.** Multi-day bulk planning. Complex product; handle as individual day plans for now.

**Scenario 8 — Nearby now.** Already out, need lunch. In-the-moment location-based search. Competes with Google Maps. Convenience feature, not differentiator.

---

## 3. NEW TAB STRUCTURE

### Before (5 tabs)

```
Today       Activities     Explore       Weekend       Settings
├─ Plan     ├─ Card list   ├─ Near you   ├─ Sunshine   ├─ Family
├─ News     ├─ Filters     ├─ Map        ├─ Snow       ├─ Prefs
            ├─ Surprise    ├─ Events     ├─ Planner
                           ├─ Museums
                           ├─ Restaurants
```

### After (3 tabs)

```
Today (Plan)              Discover                    Settings
├─ Date picker            ├─ Smart nudge (contextual) ├─ Family session
├─ City context           ├─ ☀️ Where's the sun       ├─ Calendar sync config
├─ Plan / News toggle     ├─ ❄️ Where's the snow      ├─ Home city
├─ Calendar sync          ├─ 📅 What's happening      ├─ Notifications
├─ Agenda composer        ├─ Explore nearby
├─ Execution mode         │  ├─ Activities
├─ Weather per day        │  ├─ Museums
                          │  ├─ Parks
                          │  ├─ Restaurants
                          │  ├─ Map
                          │  └─ Surprise me
                          └─ Every card: "Plan this →"
```

### Migration mapping

| Old location | Feature | New location |
|---|---|---|
| Today → Plan sub-view | Agenda composer (today/tomorrow) | Today → Plan sub-view (any date, any city) |
| Today → News sub-view | News feed, ThisDayInHistory | Today → News sub-view (unchanged) |
| Activities tab | Activity cards, filters, Surprise me | Discover → Explore nearby → Activities |
| Explore → Near you | Category browse grid | Discover → Explore nearby |
| Explore → Map | Map view | Discover → Explore nearby → Map |
| Explore → Events | Family events calendar | Discover → What's happening |
| Explore → Museums/Restaurants | Category detail screens | Discover → Explore nearby → [Category] |
| Weekend → Sunshine | Sunshine hours ranking | Discover → Where's the sun |
| Weekend → Snow | Snow/ski conditions | Discover → Where's the snow |
| Weekend → Planner | Weekend agenda composer | **Eliminated.** Merged into Today via date picker (select Sat/Sun/any date) |

### What's eliminated

- **Weekend tab planner** — the duplicate planning UI. Today's planner handles all dates via the date picker.
- **Weekend tab as a tab** — sunshine and snow move to Discover. Planning moves to Today.
- **Activities tab as a tab** — merges into Discover → Explore nearby.
- **Explore tab as a tab** — merges into Discover (events + map + categories).

### What's new (code changes)

- **Date picker on Today tab** — extends planner beyond today/tomorrow to any date within 14 days
- **City context parameter** — planner works for any city with venue data, not just Zürich
- **Smart nudge component** — proactive contextual suggestions on Discover tab
- **"Plan this →" universal CTA** — every discovery card links to planner with appropriate context
- **Anchor proximity scoring** — slots adjacent to an anchor are biased within ~20 min travel of anchor location
- **Anchor address field** — optional specific address in addition to neighbourhood

---

## 4. TODAY TAB — DETAILED SPEC

### 4a. Date picker

Replaces the current hardcoded `availablePlanDays = [.today, .tomorrow]`.

**UI:** Horizontal pill row in the header, below the title.

```
[ Today ]  [ Tomorrow ]  [ Sat ]  [ Sun ]  [ Pick date → ]
```

- `Today` and `Tomorrow` always present.
- `Sat` and `Sun` show the actual date below the day name (e.g. "22" beneath "Sat").
- `Pick date →` opens a calendar picker sheet. Maximum range: 14 days from today.
- If a date was pre-selected via a flow (e.g. "Plan around Sechseläuten on April 20"), that date appears as a named pill replacing one of the Sat/Sun slots.

**Data model change:**

```swift
// REMOVE this constant:
// let availablePlanDays: [PlanDay] = [.today, .tomorrow]

// REPLACE with:
enum PlanDay: Hashable {
    case today
    case tomorrow
    case saturday
    case sunday
    case specific(Date)

    var date: Date {
        switch self {
        case .today: return Calendar.current.startOfDay(for: Date())
        case .tomorrow: return Calendar.current.date(byAdding: .day, value: 1, to: .today)!
        case .saturday: return nextWeekday(.saturday)
        case .sunday: return nextWeekday(.sunday)
        case .specific(let d): return d
        }
    }
}

// TodayViewModel
@Published var selectedPlanDay: PlanDay = .today
```

When `selectedPlanDay` changes → invalidate `AgendaCache` for old date → trigger `composeAgendaForDate()` for new date. The `GapAnalysisEngine.analyse()` already accepts a `date: Date` parameter — no engine changes needed.

For future dates, `now` parameter to `GapAnalysisEngine` is set to 08:00 on that date (already implemented in multi-day composition, §11 of master spec).

### 4b. City context

The planner currently assumes Zürich. A new `planningCity` parameter allows the planner to operate against any city's venue data.

**Data model:**

```swift
struct PlanningCity: Codable, Equatable {
    let id: String              // "zurich", "lugano", "lucerne"
    let name: String            // "Zürich", "Lugano", "Lucerne"
    let hasFullData: Bool       // true = curated activities + restaurants
                                // false = AI-only suggestions

    static let zurich = PlanningCity(id: "zurich", name: "Zürich", hasFullData: true)
}

// TodayViewModel
@Published var planningCity: PlanningCity = .zurich
```

**Impact on composition pipeline:**

```
TodayView appears
    ↓
composeAgendaForDate(date: selectedPlanDay.date, city: planningCity)
    ↓
if city.hasFullData:
    buildScoredPool() → filter activities/restaurants to city.id
    AgendaComposer → normal Claude API call with city-specific pool
else:
    AgendaComposer → Claude API call WITHOUT venue pool
    System prompt: "Plan a family day in {city.name}. Use your general knowledge.
                    No curated venue list — suggest real places you know."
    Response includes disclaimer: "AI-suggested — we don't have curated picks for {city.name} yet"
```

**Header change:**

```
// Current:
"Today in Zürich"

// With city context:
"Today in {planningCity.name}"

// Sunshine-sourced city gets gradient header:
background: linear-gradient(180deg, terra 0%, navy 100%)  // warm → standard
```

**Cache key update:**

```swift
struct AgendaCacheKey: Hashable {
    let date: String
    let sessionHash: Int
    let anchorsHash: Int
    let cityId: String          // NEW — "zurich" default
}
```

### 4c. Header structure (revised)

```
TodayHeaderView
├── Status bar
├── Eyebrow (date string — "Tuesday, 18 March")
├── Title row: "Today in {city}" + Plan/News segment toggle
├── DatePickerRow (pill row — Today / Tomorrow / Sat / Sun / Pick date)
├── WeatherRow (per-day forecast for selected date)
├── SessionPill (👨‍👧 With Sami (3))
├── AnchorPillRow (existing — unchanged)
├── ContextBanner (existing — unchanged, gains city-aware copy)
```

**Context banner city-aware variants:**

```swift
var contextBannerText: String {
    if planningCity != .zurich && planningCity.hasFullData {
        return "Sunny day in \(planningCity.name). Built a full day for \(session.childrenDisplay)."
    }
    if planningCity != .zurich && !planningCity.hasFullData {
        return "AI-suggested plan for \(planningCity.name). We don't have curated picks here yet."
    }
    // ... existing Zürich-specific variants unchanged
}
```

### 4d. News sub-view

Unchanged. Stays behind the Plan/News toggle. Contains TransportAlertView, ThisDayInHistoryView, NewsFeedView.

If News is low-engagement in practice, consider moving it to Discover in a future pass. Not in scope for this restructure.

---

## 5. DISCOVER TAB — DETAILED SPEC

### 5a. Screen structure

```
DiscoverView
├── DiscoverHeaderView
│   ├── Status bar
│   ├── Eyebrow ("Explore")
│   └── Title ("Discover")
│
└── ScrollView
    ├── SmartNudgeCard (conditional — see §5b)
    ├── DestinationHeroCards
    │   ├── SunshineHeroCard → SunshineRankingView → CityDetailView
    │   ├── SnowHeroCard → SnowConditionsView → ResortDetailView
    │   └── EventsHeroCard → EventsCalendarView → EventDetailView
    ├── ExploreNearbySection
    │   ├── SectionHeader ("Explore nearby")
    │   ├── BrowseGrid (2×2: Activities, Museums, Parks, Restaurants)
    │   ├── MapButton → MapView
    │   └── SurpriseMeButton
    └── BottomPadding
```

### 5b. Smart nudge

A contextual card that appears at the top of Discover when conditions are met. Only one nudge at a time. Priority order:

**1. Sunshine escape (highest priority)**
Condition: Current city weather is poor (overcast/rain, < 12°C) for 2+ consecutive weekends AND a covered city has sunshine forecast (> 6 hrs, > 16°C) for the coming weekend.

```
┌─────────────────────────────────────────┐
│ ☀️ 3 grey weekends — time to escape?   │
│ It's 19° and sunny in Lugano this      │
│ Saturday. Just 2h by train.            │
│                                         │
│ Plan a sunshine day →                   │
└─────────────────────────────────────────┘
```

Tap → navigates to SunshineRankingView (or directly to CityDetailView if the nudge names a specific city).

**2. Upcoming event**
Condition: A plannable CityEvent is within 3 weeks and the user has not created an anchor for its date.

```
┌─────────────────────────────────────────┐
│ 📅 Sechseläuten is in 3 weeks          │
│ Spring festival with the Böögg         │
│ burning. Plan your April 20?           │
│                                         │
│ Plan around this →                      │
└─────────────────────────────────────────┘
```

Tap → opens AnchorFormSheet pre-filled with event.

**3. Snow alert (winter only)**
Condition: November–April. A resort has > 20cm fresh snow in the past 48 hours.

```
┌─────────────────────────────────────────┐
│ ❄️ 35cm fresh snow at Flumserberg      │
│ Best conditions this season.           │
│ 1h 15m by car.                         │
│                                         │
│ Plan a ski day →                        │
└─────────────────────────────────────────┘
```

**Data model:**

```swift
enum NudgeType: Equatable {
    case sunshineEscape(city: PlanningCity, temp: Int, sunHours: Double)
    case upcomingEvent(event: CityEvent)
    case snowAlert(resort: String, freshCm: Int, travelTime: String)
}

struct SmartNudge: Identifiable {
    let id: UUID
    let type: NudgeType
    let createdDate: Date
    var dismissed: Bool
}

class NudgeEngine {
    func evaluate(
        localWeather: [WeatherData],      // last 14 days + 7 day forecast
        sunshineRanking: [CityForecast],
        snowConditions: [ResortCondition],
        events: [CityEvent],
        existingAnchors: [AnchorEvent]
    ) -> SmartNudge?
}
```

### 5c. Destination hero cards

Three hero cards linking to the destination finders. Each is a rounded card with a gradient background, title, subtitle, and a badge.

**SunshineHeroCard**
- Background: warm gradient (gold → terracotta)
- Title: "Where's the sun?"
- Subtitle: "Find the sunniest spot nearby"
- Badge: "☀️ {n} cities" (number of cities with forecast data)
- Tap → pushes `SunshineRankingView`
- Seasonal: always visible (sunshine is relevant year-round)

**SnowHeroCard**
- Background: cool gradient (light blue → navy)
- Title: "Where's the snow?"
- Subtitle: "Fresh powder & ski conditions"
- Badge: "❄️ Season" or specific conditions
- Tap → pushes `SnowConditionsView`
- Seasonal: visible November–April only. Hidden in summer.

**EventsHeroCard**
- Background: green → navy gradient
- Title: "What's happening"
- Subtitle: "Events, markets & festivals"
- Badge: "{n} this week" (count of upcoming events within 7 days)
- Tap → pushes `EventsCalendarView`
- Always visible.

### 5d. Sunshine flow (Flow B)

```
DiscoverView
    → SunshineRankingView (ranked list of cities by sunshine hours for selected day)
        → CityDetailView (city info + things to do + "Plan a day here →" CTA)
            → [tap CTA] → navigates to Today tab with:
                - selectedPlanDay = .specific(selectedDate)
                - planningCity = tapped city
                - header gradient = sunshine warm
```

**SunshineRankingView:**

Existing sunshine ranking feature from Weekend tab, relocated. Shows cities ranked by forecast sunshine hours for the selected day.

Each row:
```
[ rank ]  [ city name     ]  [ sun hours ]
          [ temp · weather · travel time ]
```

Add a date selector at the top (Saturday/Sunday toggle, or day picker for the coming 7 days).

Current user's city appears in the list but dimmed if it has low sunshine. This contextualises the escape — "Zürich has 1.2 hrs, Lugano has 9.2 hrs."

**CityDetailView:**

New screen. Shows:
- City header with weather badge and travel time
- **Primary CTA: "Plan a day in {city} →"** — prominent, terracotta background
- Things to do (activities list filtered to this city, if `hasFullData`)
- Each activity card has its own "Plan around this →" link
- For cities without full data: show "We're expanding here soon" + primary CTA still works (AI mode)

### 5e. Snow flow

Same pattern as sunshine. `SnowConditionsView` → `ResortDetailView` → "Plan a ski day →" → Today tab with city context.

Existing Weekend tab snow feature, relocated.

### 5f. Events flow

Existing Explore → Events feature, relocated to Discover → What's happening.

**EventsCalendarView:**
- Shows events grouped by: "This weekend", "Coming up", "School holidays"
- Each plannable event has "Plan around this →"
- Non-plannable events (holiday blocks) show informational text only: "{n} days off — plan day by day in the planner"

**"Plan around this →" action:**
1. Opens AnchorFormSheet as a sheet (not a tab switch)
2. Pre-filled: title, category. If event has time window, show it as context with default.
3. User adds timing + duration (required)
4. On save: creates anchor for event's date
5. Navigates to Today tab with `selectedPlanDay = .specific(event.date)`
6. Planner composes around the new anchor

### 5g. Explore nearby

Existing Activities tab + Explore tab category browsing, merged into a section within Discover.

**BrowseGrid** — 2×2 grid of category tiles:
```
🎨 Museums     🌳 Parks
🍽️ Restaurants  🎯 Activities
```

Each tile → pushes the existing category detail view (activity cards with filters).

**SurpriseMeButton** — existing feature from Activities tab, relocated below the grid.

**MapButton** — existing map view from Explore tab, accessible from Explore nearby section.

**Every activity/restaurant card in these views gains a "Plan around this →" link**, following the same anchor form → Today tab flow as events.

---

## 6. ANCHOR LOCATION & PROXIMITY SCORING

### 6a. Anchor form update

The AnchorFormSheet gains an address step. New 6-step form:

```
Step 1: What        (free text, pre-fill from event/calendar)
Step 2: What kind   (category grid — required)
Step 3: When        (time picker — required. If event has time window, show context + default)
Step 4: How long    (duration segments — required)
Step 5: Where       (neighbourhood chips — required)
Step 6: Address     (text field — optional. Pre-fill from EventKit location if available)
```

**Data model addition to AnchorEvent:**

```swift
struct AnchorEvent: Codable, Identifiable {
    // ... existing fields ...
    var address: String?                // NEW — optional specific address
    var lat: Double?                    // NEW — geocoded from address, or from EventKit
    var lon: Double?                    // NEW — geocoded from address, or from EventKit

    var hasLocation: Bool {
        lat != nil && lon != nil
    }
}
```

**Geocoding:** If user enters an address in step 6, geocode using `CLGeocoder` to get lat/lon. If anchor came from EventKit and the calendar event has a structured location, extract lat/lon directly.

### 6b. Proximity scoring

When filling a gap that is adjacent to an anchor with a known location, the venue pool is filtered by proximity.

**Rule:** Slots immediately before or after an anchor should prefer venues within ~20 minutes travel. Venues beyond 20 minutes are deprioritised (not hard-excluded).

**Implementation — in `buildScoredPool()` or as a post-filter:**

```swift
func applyProximityBias(
    venues: [Activity],  // or [Restaurant]
    adjacentAnchor: AnchorEvent?,
    maxTravelMinutes: Int = 20
) -> [Activity] {
    guard let anchor = adjacentAnchor, anchor.hasLocation else {
        return venues  // no location data → no bias
    }

    return venues.map { venue in
        let distance = haversineDistance(
            lat1: anchor.lat!, lon1: anchor.lon!,
            lat2: venue.lat, lon2: venue.lon
        )
        let estimatedMinutes = estimateTravelMinutes(distanceKm: distance)
        let proximityScore: Double
        if estimatedMinutes <= Double(maxTravelMinutes) {
            proximityScore = 1.0
        } else {
            // Soft penalty — gradually reduce score beyond 20 min
            proximityScore = max(0.2, 1.0 - (estimatedMinutes - Double(maxTravelMinutes)) / 30.0)
        }
        return (venue, proximityScore)
    }
    .sorted { $0.1 > $1.1 }
    .map { $0.0 }
}
```

**Where applied:** Before passing the scored pool to `AgendaComposer`, apply proximity bias to the activities/restaurants that will fill the gap immediately before or after an anchor. Gaps not adjacent to an anchor are unaffected.

**Claude API prompt addition:**

Add to the system prompt (§4c of master spec):
```
12. If an anchor has a location, slots immediately before or after it should be
    geographically close (within 20 minutes). The venue pool is pre-sorted by proximity
    for these gaps — prefer venues appearing earlier in the list.
```

---

## 7. FLOW ROUTING

How every entry point connects to the planner. All paths end at the Today tab.

| Entry point | Source tab | Context passed to Today | Anchor created? |
|---|---|---|---|
| Open app, no plans | Today | None. Auto-compose for today. | No |
| Calendar event synced | Today | Anchor from EventKit with time, duration, location | Yes (auto) |
| User adds anchor manually | Today | User-entered anchor | Yes (manual) |
| "Plan around this" on CityEvent | Discover → Events | Anchor from AnchorFormSheet. Date pre-selected. | Yes (manual) |
| "Plan a day in {city}" from sunshine | Discover → Sunshine | `planningCity` set. Date pre-selected. | No |
| "Plan a ski day" from snow | Discover → Snow | `planningCity` set to resort city. Date pre-selected. | No |
| "Plan around this" on activity card | Discover → Nearby | Activity as anchor. | Yes (manual) |
| Smart nudge → sunshine escape | Discover | `planningCity` set. Date pre-selected. | No |
| Smart nudge → upcoming event | Discover | Opens AnchorFormSheet → anchor created → Today | Yes (manual) |
| Push notification | Deep link | Date + context pre-loaded | Depends on type |

**Navigation mechanics:**

When Discover triggers a navigation to Today:
1. Set `selectedPlanDay` on `TodayViewModel`
2. Set `planningCity` on `TodayViewModel` (if city context)
3. Set `selectedTab = .today` on the root tab controller
4. If anchor was created, it triggers `AnchorStore.didChangeNotification` → recompose

This is a programmatic tab switch + state injection. No custom navigation stack needed.

---

## 8. WHAT HAPPENS TO EXISTING WEEKEND TAB CODE

The Weekend tab currently contains three segments: Sunshine, Snow, Planner.

**Sunshine segment** → moves to `DiscoverView` → `SunshineHeroCard` → `SunshineRankingView`. The existing `SunshineView` / `WeekendSunshineView` is reused as-is, just re-parented under Discover's navigation stack.

**Snow segment** → moves to `DiscoverView` → `SnowHeroCard` → `SnowConditionsView`. Same re-parenting.

**Planner segment** → eliminated. Its functionality is fully covered by the Today tab with the date picker. The existing `WeekendView` planner code that calls `composeWeekend()` can be removed. The `composeWeekend()` function itself is replaced by calling `composeAgendaForDate()` with Saturday/Sunday dates — which already works (it's the same function, called per-day).

**Files affected:**

```
WeekendView.swift             — DELETE (replaced by DiscoverView + Today date picker)
WeekendResponse.swift         — KEEP (DayWeather model used by SunshineRankingView)
WeekendSunshineView.swift     — MOVE to Discover navigation stack (rename optional)
WeekendSnowView.swift         — MOVE to Discover navigation stack (rename optional)
```

---

## 9. WHAT HAPPENS TO EXISTING ACTIVITIES TAB CODE

The Activities tab is a card list with category filters and "Surprise me."

**Activity card list** → moves to `DiscoverView` → Explore nearby → Activities. The existing `ActivitiesView` / `ActivityListView` is re-parented under Discover. Filters and card expand-in-place behaviour unchanged.

**Surprise me** → moves to Discover → Explore nearby section, below the browse grid. Same logic, different location.

**Files affected:**

```
ActivitiesView.swift          — MOVE to Discover navigation stack
ActivityCard.swift            — KEEP (unchanged, gains "Plan around this →" link)
```

### "Plan around this" on activity cards

New addition to `ActivityCard` expanded state:

```swift
// In ActivityCard expanded view, add below existing content:
Button("Plan around this →") {
    // 1. Open AnchorFormSheet pre-filled:
    //    - title: activity.name
    //    - category: .activity
    //    - neighbourhood: derived from activity.lat/lon
    // 2. On save: create anchor, navigate to Today tab
}
.font(.custom("DMSans", size: 12))
.foregroundColor(.terra)
```

---

## 10. WHAT HAPPENS TO EXISTING EXPLORE TAB CODE

The Explore tab contains: Near you, Browse by type grid, Map, Events (family calendar), and category detail screens (Museums, Restaurants, etc).

**Near you + Browse grid** → becomes the "Explore nearby" section in Discover. The existing grid tiles and "near you" distance sorting are reused.

**Map** → accessible from Explore nearby section in Discover. Existing `MapView` re-parented.

**Events** → becomes `Discover → What's happening`. The existing `EventsCalendarView` / `ExploreCalendarView` is re-parented. The "Add to plan" CTA already exists (built in Step 17 of master spec) — rename to "Plan around this →" for consistency.

**Category detail screens** (Museums, Restaurants, etc) → pushed from the browse grid in Discover, same as before. Re-parented.

**Files affected:**

```
ExploreView.swift             — DELETE (replaced by DiscoverView)
ExploreCalendarView.swift     — MOVE to Discover → Events
ExploreMapView.swift          — MOVE to Discover → Explore nearby
ExploreCategoryView.swift     — MOVE to Discover → Explore nearby → [Category]
```

---

## 11. NEW FILES

```
DiscoverView.swift                 — Main Discover tab view (hub with hero cards + browse grid)
DiscoverHeaderView.swift           — Header for Discover tab
SmartNudgeCard.swift               — Contextual nudge card component
NudgeEngine.swift                  — Logic for evaluating which nudge to show
SunshineHeroCard.swift             — Hero card for sunshine finder
SnowHeroCard.swift                 — Hero card for snow finder
EventsHeroCard.swift               — Hero card for events calendar
CityDetailView.swift               — City info + things to do + "Plan a day here" CTA
PlanningCity.swift                 — City context model
DatePickerRow.swift                — Date pill row component for Today header
PlanDay.swift                      — Date enum (today/tomorrow/sat/sun/specific)
```

---

## 12. DATA MODEL CHANGES SUMMARY

### New models

```swift
PlanningCity                    // §4b — city context for planner
PlanDay                         // §4a — date selection enum
SmartNudge + NudgeType          // §5b — nudge data
NudgeEngine                     // §5b — nudge evaluation
```

### Modified models

```swift
AnchorEvent                     // §6a — add address, lat, lon fields
AgendaCacheKey                  // §4b — add cityId field
TodayViewModel                  // §4a, §4b — add selectedPlanDay, planningCity
```

### Unchanged models

Everything else. GapAnalysisEngine, FreshnessScorer, AgendaComposer, AgendaSlot, DayAgenda, VenueVisit, VenueVisitStore, FamilySession, CheckInRecord, TimelineShifter, FeasibilityChecker, GeofenceMonitor, AgendaNotificationScheduler, execution mode, custom slots, reflow — all unchanged.

---

## 13. BUILD ORDER

Do in sequence. Each step independently testable. Steps 1–4 are structural. Steps 5–7 add new capabilities.

**Step 1 — Create DiscoverView shell**
- New `DiscoverView` with header, scroll view, placeholder sections
- Hero cards (sunshine, snow, events) as tappable cards — navigation targets are existing views
- Explore nearby browse grid linking to existing category views
- Move `SurpriseMeButton` to Discover
- Tab bar: swap 5 tabs → 3 tabs (Today, Discover, Settings)
- **Test:** All three tabs render. Discover shows hero cards and grid. Tapping hero cards pushes existing sunshine/snow/events views. Explore nearby tiles push existing category views.

**Step 2 — Relocate Activities tab content**
- Move `ActivitiesView` into Discover → Explore nearby → Activities
- Ensure filters, expand-in-place, Surprise me work in new location
- Remove Activities tab from tab bar
- **Test:** Activity cards render in Discover → Activities. Filters work. Surprise me works.

**Step 3 — Relocate Explore tab content**
- Move events calendar, map, category screens into Discover
- Remove Explore tab from tab bar
- Rename "Add to plan" CTA to "Plan around this →" on event cards
- **Test:** Events calendar accessible from Discover → What's happening. Map accessible from Discover → Explore nearby. "Plan around this" on events still creates anchors.

**Step 4 — Relocate Weekend tab content**
- Move sunshine ranking to Discover → Where's the sun
- Move snow conditions to Discover → Where's the snow
- Remove Weekend tab from tab bar
- Delete `WeekendView.swift` planner segment
- **Test:** Sunshine ranking accessible from Discover. Snow conditions accessible from Discover. Weekend tab gone.

**Step 5 — Date picker on Today tab**
- Add `DatePickerRow` to `TodayHeaderView`
- Add `PlanDay` enum and `selectedPlanDay` to `TodayViewModel`
- Wire date selection → `composeAgendaForDate()` with selected date
- "Pick date →" opens calendar sheet (max 14 days)
- **Test:** Select Saturday → planner composes for Saturday. Select a future date → planner composes for that date. Switching dates invalidates and recomposes.

**Step 6 — City context**
- Add `PlanningCity` model
- Add `planningCity` to `TodayViewModel`
- Add `cityId` to `AgendaCacheKey`
- Wire `planningCity` into `buildScoredPool()` — filter venue pool by city
- AI-only mode for cities without curated data
- Header: "Today in {city}" with gradient for non-Zürich
- Build `CityDetailView` with "Plan a day in {city} →" CTA
- Wire sunshine ranking → city detail → Today tab navigation
- **Test:** Tap sunshine city → city detail → "Plan a day here" → Today tab shows "Today in Lugano" with Lugano venues. AI-only mode works for uncovered cities.

**Step 7 — Smart nudge + anchor proximity**
- Build `NudgeEngine` evaluation logic
- Build `SmartNudgeCard` component
- Wire nudge into DiscoverView (conditional, top of scroll)
- Add `address`, `lat`, `lon` to `AnchorEvent`
- Add address step to `AnchorFormSheet`
- Implement `applyProximityBias()` for anchor-adjacent gaps
- Add proximity rule to Claude API system prompt
- **Test:** Nudge appears when conditions met. Anchor with address → adjacent slots prefer nearby venues.

---

## 14. DESIGN TOKENS — ADDITIONS

All existing design tokens unchanged. New tokens for Discover tab:

```swift
// Sunshine hero gradient
Color.sunshineGradientStart = Color(hex: "#F5C842")
Color.sunshineGradientEnd = Color(hex: "#C4623A")

// Snow hero gradient
Color.snowGradientStart = Color(hex: "#B8D4E8")
Color.snowGradientEnd = Color(hex: "#4A7A9C")

// Events hero gradient
Color.eventsGradientStart = Color(hex: "#3A7D5C")
Color.eventsGradientEnd = Color(hex: "#1A3A5C")

// Nudge card
Color.nudgeBackground = linear gradient from sunshineGradientStart.opacity(0.12) to terra.opacity(0.08)
Color.nudgeBorder = terra.opacity(0.15)

// City context header (non-Zürich planning)
Color.cityHeaderGradientStart = Color(hex: "#C4623A")  // terra
Color.cityHeaderGradientEnd = Color(hex: "#1A3A5C")    // navy
```

---

## 15. OPEN QUESTIONS

1. **News sub-view** — does it stay in Today behind the Plan/News toggle, or move to Discover as a "Local news" section? Depends on engagement data. Default: keep it in Today for now.

2. **Farmers market and recurring events** — these have fixed time windows and locations. The anchor form could pre-fill time/duration/location from event data. Deferred — requires `startTime`, `endTime`, `location`, `lat`, `lon` fields on CityEvent schema. Not in this pass.

3. **Multi-day trip planning** — Easter weekend = 4 days. The date picker supports individual day selection. Multi-day mode (compose all days at once with cross-day dedup) is a future enhancement. For now: plan each day individually via the date picker.

4. **Venue data coverage** — 7 cities have full data. How often does sunshine point to uncovered cities? If > 50% of sunshine recommendations hit AI-only mode, the degraded experience dominates. Consider biasing sunshine ranking toward covered cities, or expanding coverage to top 3 sunshine destinations.

5. **Tab naming** — "Today" vs "Plan" for the first tab. "Today" implies present-day; "Plan" is more accurate since it handles any date. Consider: keep "Today" for familiarity, the date picker makes the extended scope obvious.

---

## 16. NOT IN THIS PASS

- Farmers market / recurring event time pre-fill (requires CityEvent schema expansion)
- Multi-day composition mode (plan whole weekend at once)
- Push notification deep links to specific flows
- Saved plans / plan history
- Venue data expansion to new cities
- Recurring anchors (weekly football training)
- Apple Calendar two-way write-back
- Adaptive timing from check-in deltas
