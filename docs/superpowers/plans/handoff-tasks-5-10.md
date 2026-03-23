# Znuni Rearchitecture — Handoff: Tasks 5–10

> **For Xcode Claude or any agentic worker continuing implementation.**
> Tasks 1–4 are complete. The app is restructured to 3 tabs. This document
> covers what was done and what remains.

---

## What's Done (Tasks 1–4)

### Task 1: 3-Tab Structure
- `AppTab` enum reduced from 5 to 3 cases: `.today`, `.discover`, `.settings`
- `ContentView.swift` rewritten: `DiscoverNavigationStack` replaces `ExploreNavigationStack` + `WeekendTabView`
- `DiscoverRoute` enum defined with 9 routes (sunshine, snow, events, activities, restaurants, museums, parks, deals, map)
- All navigation destinations wired to existing views
- Deep links updated: activities/explore/lunch/events/weather/weekend → `.discover`
- `pendingExploreRoute` renamed to `pendingDiscoverRoute`
- `ZnuniTabBar` renders 3 tabs with Canvas icons (news grid, mountain, gear)

### Task 2: Sunshine & Snow Hero Cards
- `SunshineHeroCard.swift` — warm gradient card in Discover
- `SnowHeroCard.swift` — cool gradient card, visible Nov–Apr only
- Both are `Button` + `.buttonStyle(.plain)` wrapping the card, pushing `DiscoverRoute`

### Task 3: Events Hero Card & Browse Grid
- `EventsHeroCard.swift` — green→navy gradient with upcoming count badge
- `ExploreNearbySection.swift` — 2×2 browse grid (Activities, Museums, Parks, Restaurants) + "View map" button
- Event CTA renamed from "Add to your plan" → "Plan around this →" in both `EventCard.swift` and `DayDetailView.swift`
- `DiscoverView.swift` updated with all hero cards + browse grid

### Task 4: Cleanup
- Deleted: `WeekendView.swift`, `WeekendDayCard.swift`, `WeekendViewModel.swift`, `ExploreView.swift`, `ExploreHeroBanner.swift`
- Kept: `BrowseByTypeSection.swift` (has Canvas illustrations worth migrating to `ExploreNearbySection`)
- Kept: All sunshine, snow, events, activities, lunch, explore map, category detail views
- Kept: `WeekendResponse.swift` (model used by sunshine/weather)
- Stale comments updated in `TodayViewModel.swift` and `ExploreMapOverlay.swift`

### Design Tokens Added
In `Color+Theme.swift`:
- `sunshineGradientStart/End` (gold → terracotta)
- `snowGradientStart/End` (light blue → navy)
- `eventsGradientStart/End` (green → navy)

### Build Status
- **BUILD SUCCEEDED** on all 4 tasks
- Branch: `claude/plan-ios-app-4aOQo`
- 4 commits on branch

---

## What Remains (Tasks 5–10)

Full task details are in the implementation plan at:
`/Users/bq/Documents/Znuni/docs/superpowers/plans/2026-03-16-rearchitecture-3-tabs.md`

The authoritative spec is at:
`/Users/bq/Documents/Znuni/design system/znuni-rearchitecture-spec-v2.md`

### Task 5: Date Picker on Today Tab

**Goal:** Extend the planner from today/tomorrow/sat/sun to any date within 14 days.

**Files to create:**
- `Views/Today/DatePickerRow.swift` — horizontal pill row (Today / Tomorrow / Sat 22 / Sun 23 / Pick date →)
- `Views/Today/DatePickerSheet.swift` — calendar sheet with 14-day range

**Files to modify:**
- `Models/DayAgenda.swift` — `PlanDay` enum lives here (line ~6). Add `.specific(Date)` case. **Remove `CaseIterable` conformance** (associated values break it). Update `date()` func and `isoDate`.
- `ViewModels/TodayViewModel.swift` — wire `selectedPlanDay` changes to `composeAgendaForSelectedDay()`. The existing function already handles date-based composition. **Also: remove `composeWeekend()`, `isWeekendMode`, and `_weekendWeather`** — weekend planning is now handled by selecting Saturday/Sunday in the date picker. Search for `PlanDay.allCases` and update (no longer valid after removing CaseIterable).
- `Views/Today/TodayView.swift` or `Views/Today/TodayHeroBanner.swift` — add `DatePickerRow` below the weather row in Plan mode.

**Key detail:** `composeAgendaForDate()` already accepts a `planDate: Date` parameter. For future dates, `now` is set to 08:00 on that date (already implemented). The engine handles this.

### Task 6: City Context + Planner CTA on City Cards

**Goal:** The planner can work for any of the 7 covered cities, not just Zürich. Sunshine/snow cards get a "Plan a day here" CTA.

**Files to create:**
- `Models/PlanningCity.swift` — struct with `id`, `name`, static `coveredCities` list (zurich, basel, bern, geneva, lausanne, luzern, winterthur), `isCovered()` method.

**Files to modify:**
- `ViewModels/TodayViewModel.swift` — add `@Published var planningCity: PlanningCity = .zurich`. Filter venue pool by `planningCity.id` in `composeAgendaForDate()`. Pass `planningCity.id` to `AgendaCache.shared.get/store()` (the `city` parameter already exists, defaults to "zurich").
- `Views/Today/TodayHeroBanner.swift` — change "Today in *Zürich*" to "Today in *{planningCity.name}*".
- `Views/Sunshine/SunshineCard.swift` — add conditional "Plan a day in {city} →" CTA in expanded state, only when `PlanningCity.isCovered(destination.id)`. On tap: set `todayViewModel.planningCity`, set `selectedPlanDay`, switch `appState.selectedTab = .today`. Needs access to TodayViewModel and AppState (via environment or closure).
- `Views/Snow/SnowCard.swift` — same CTA pattern.

**Key detail:** `AgendaCache` already takes a `city` parameter. No structural cache change needed.

### Task 7: Smart Nudge Engine

**Goal:** Proactive contextual nudges at top of Discover tab.

**Files to create:**
- `Services/NudgeEngine.swift` — evaluates conditions (poor weather + sunny destination, upcoming plannable event, fresh snow) and returns highest-priority nudge.
- `Views/Discover/SmartNudgeCard.swift` — renders nudge card with appropriate gradient and CTA.

**Files to modify:**
- `Views/Discover/DiscoverView.swift` — evaluate `NudgeEngine` on appear, show `SmartNudgeCard` at top of scroll.

**Key detail:** Sunshine escape nudge should recommend ANY sunny destination (not just covered cities). Only the "Plan a day here" CTA on the sunshine card is gated by `isCovered`.

### Task 8: Anchor Location & Proximity Scoring

**Goal:** Anchor events can have addresses. Slots adjacent to anchors with locations prefer nearby venues.

**Files to modify:**
- `Models/DayAnchor.swift` — add `address: String?`, `lat: Double?`, `lon: Double?`, computed `hasLocation`.
- `Views/Today/AnchorFormSheet.swift` — add Step 6 (optional address field with `CLGeocoder`). Also add `AnchorPrefill` struct for pre-filling from "Plan around this" flow (title, category, lat, lon, date).
- `Services/FreshnessScorer.swift` — add `applyProximityBias()` static function. Call it in `buildScoredPool()` for gaps adjacent to anchors with locations.
- `Services/AgendaComposer.swift` — add rule 12 to system prompt about geographic proximity.

### Task 9: "Plan Around This" Universal CTA

**Goal:** Every activity/restaurant card gets a "Plan around this →" link.

**Files to modify:**
- `Views/Activities/ActivityCard.swift` — add CTA in expanded state. On tap: present `AnchorFormSheet` pre-filled with activity data, then navigate to Today tab.
- `Views/Lunch/LunchCard.swift` — same pattern.

**Depends on:** Task 8 (AnchorFormSheet pre-fill support).

### Task 10: Final Verification

Build, install on simulator, manually test all flows:
- 3 tabs render correctly
- Discover hero cards → sunshine/snow/events
- Browse grid → activities/museums/parks/restaurants
- Date picker → compose for any date
- City context → "Today in {city}" header
- "Plan around this" → anchor form → Today tab

---

## Architecture Reference

### DiscoverRoute enum (defined in ContentView.swift)
```swift
enum DiscoverRoute: Hashable {
    case sunshine, snow, events, activities, restaurants, museums, parks, deals, map
}
```

### Navigation pattern
From Discover, push routes via `path.append(DiscoverRoute.sunshine)`.
From Discover to Today: set state on `TodayViewModel`, then `appState.selectedTab = .today`.

### View model ownership
`DiscoverNavigationStack` in ContentView.swift creates these `@State` view models:
- `ExploreViewModel` (shared by CategoryDetailView, map)
- `SunshineViewModel`
- `SnowViewModel`
- `EventsViewModel`
- `ActivitiesViewModel`
- `LunchViewModel`

`TodayNavigationStack` owns `TodayViewModel` via the existing pattern.

### Key files
| File | Lines | What |
|------|-------|------|
| `App/ContentView.swift` | ~500 | Tab bar, navigation stacks, DiscoverRoute |
| `App/AppState.swift` | ~280 | AppTab (3 cases), deep links, global state |
| `Views/Discover/DiscoverView.swift` | ~80 | Hero cards + browse grid hub |
| `ViewModels/TodayViewModel.swift` | ~1940 | Central planner logic |
| `Models/DayAgenda.swift` | ~370 | PlanDay enum, AgendaSlot, DayAgenda |
| `Services/AgendaComposer.swift` | ~316 | Claude API prompt + parsing |
| `Services/FreshnessScorer.swift` | ~197 | Venue scoring + pool building |
| `Services/AgendaCache.swift` | ~64 | Disk cache with city param |

### What NOT to touch
- `GapAnalysisEngine.swift` — works as-is
- `TemplateEngine.swift` — works as-is
- `CalendarService.swift` and sync files — work as-is
- `AnchorStore.swift` — works as-is
- Execution mode files — work as-is

---

## Known Issues / Notes

1. **BrowseByTypeSection.swift** has Canvas illustrations (museum, park, restaurant, playground, lake) that `ExploreNearbySection.swift` doesn't have. Consider migrating the Canvas art to the new browse grid for visual richness.

2. **EventCard "Plan around this →"** CTA currently only shows for today's plannable events (`event.isPlannable && event.overlaps(with: Date())`). Task 5 should remove the `isToday` gate so it works for any date.

3. **`composeWeekend()` in TodayViewModel** is still present (~line 520). Task 5 should remove it along with `isWeekendMode` and `_weekendWeather`.

4. **DealsView doesn't exist** — the `.deals` route in DiscoverNavigationStack currently shows a placeholder `Text("Deals coming soon")`. Either create a proper DealsView or route through CategoryDetailView.

5. **DiscoverView event count** is hardcoded to 0 (`EventsHeroCard(upcomingCount: 0)`). Wire to real data from ExploreViewModel or EventsViewModel.
