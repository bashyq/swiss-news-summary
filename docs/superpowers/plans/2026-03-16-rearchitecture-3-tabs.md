# Znuni 3-Tab Rearchitecture Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the Znuni iOS app from 5 feature-organised tabs (Today, Activities, Explore, Weekend, Settings) to 3 intent-organised tabs (Today, Discover, Settings), unifying planning into a single surface with a date picker and city context.

**Architecture:** All existing view components are preserved — nothing is deleted except the Weekend Planner duplicate. Views are relocated into new navigation hierarchies. The planner engine (GapAnalysisEngine, FreshnessScorer, AgendaComposer) is untouched. New capabilities (date picker, city context, smart nudge, proximity scoring) layer on top of existing infrastructure.

**Tech Stack:** SwiftUI (iOS 17+), @Observable view models, NavigationStack, existing Cloudflare Worker API.

**Spec:** `/Users/bq/Documents/Znuni/design system/znuni-rearchitecture-spec-v2.md`

**Mockups:** `/Users/bq/Documents/Znuni/design system/znuni-user-flows.html`

---

## File Map

### New files to create

| File | Purpose |
|------|---------|
| `Views/Discover/DiscoverView.swift` | Main Discover tab — hub with smart nudge, hero cards, browse grid |
| `Views/Discover/DiscoverHeroBanner.swift` | Navy gradient header for Discover tab |
| `Views/Discover/SunshineHeroCard.swift` | Tappable hero card linking to sunshine ranking |
| `Views/Discover/SnowHeroCard.swift` | Tappable hero card linking to snow conditions |
| `Views/Discover/EventsHeroCard.swift` | Tappable hero card linking to events calendar |
| `Views/Discover/ExploreNearbySection.swift` | Browse grid (2×2) + map + surprise me |
| `Views/Discover/SmartNudgeCard.swift` | Contextual nudge card component |
| `Views/Today/DatePickerRow.swift` | Horizontal date pill row (Today/Tomorrow/Sat/Sun/Pick date) |
| `Views/Today/DatePickerSheet.swift` | Calendar sheet for picking dates up to 14 days out |
| `Models/PlanningCity.swift` | City context model with `coveredCities` list |
| `Services/NudgeEngine.swift` | Evaluates which smart nudge to show |
| `Views/Deals/DealsView.swift` | Deals list view (currently missing — needed for Discover → Deals route) |

### Files to modify

| File | Change |
|------|--------|
| `App/AppState.swift` | `AppTab` enum: 5 tabs → 3 tabs. Remove `.activities`, `.explore`, `.weekend`. Add `.discover`. |
| `App/ContentView.swift` | Rewrite tab bar and navigation stacks for 3 tabs. Create `DiscoverNavigationStack`. Delete `ExploreNavigationStack`, `WeekendTabView`. |
| `Views/Today/TodayView.swift` | Add `DatePickerRow` to Plan mode header. Wire date selection. |
| `Views/Today/TodayHeroBanner.swift` | Support city context in title ("Today in {city}"). Add date pill row slot. |
| `Models/DayAgenda.swift` | Extend `PlanDay` enum with `.specific(Date)` case. Remove `CaseIterable` conformance. |
| `ViewModels/TodayViewModel.swift` | Add `planningCity: PlanningCity`. Wire date picker → composition. Remove `composeWeekend()` and `isWeekendMode` (absorbed by date picker selecting Sat/Sun). Update `availablePlanDays` computed property. |
| `Views/Sunshine/SunshineCard.swift` | Add conditional "Plan a day in {city} →" CTA for covered cities. |
| `Views/Snow/SnowCard.swift` | Add conditional "Plan a ski day →" CTA for covered cities. |
| `Views/Events/EventCard.swift` | Rename "Add to plan" → "Plan around this →" for consistency. |
| `Views/Activities/ActivityCard.swift` | Add "Plan around this →" link in expanded state. |
| `Views/Lunch/LunchCard.swift` | Add "Plan around this →" link in expanded state. |
| `Models/DayAnchor.swift` | Add `address: String?`, `lat: Double?`, `lon: Double?` fields. |
| `Views/Today/AnchorFormSheet.swift` | Add Step 6 (address) to the form. |
| `Services/AgendaComposer.swift` | Add proximity rule to system prompt. |
| `Services/FreshnessScorer.swift` | Add `applyProximityBias()` for anchor-adjacent gaps. |
| `Extensions/Color+Theme.swift` | Add sunshine/snow/events gradient tokens, nudge colors. |
| `Views/Events/EventCard.swift` | Update "Add to your plan" CTA: rename, extend to work on any date (not just today), wire full navigation flow. |
| `Views/Events/DayDetailView.swift` | Same CTA updates as EventCard. |
| `Views/Today/AnchorFormSheet.swift` | Add Step 6 (address). Accept optional pre-fill parameters (title, category, lat, lon) for "Plan around this" flow. |

### Files to delete

| File | Reason |
|------|--------|
| `Views/Weekend/WeekendView.swift` | Planner duplicate — replaced by Today date picker. |
| `Views/Weekend/WeekendDayCard.swift` | Only used by WeekendView planner. |
| `ViewModels/WeekendViewModel.swift` | Thin wrapper — functionality absorbed by TodayViewModel. |

### Files relocated (moved into Discover navigation stack, no content changes)

| File | Old parent | New parent |
|------|-----------|------------|
| `Views/Sunshine/SunshineView.swift` | Weekend tab | Discover → "Where's the sun" |
| `Views/Snow/SnowView.swift` | Weekend tab | Discover → "Where's the snow" |
| `Views/Events/EventsView.swift` | Explore → Events | Discover → "What's happening" |
| `Views/Activities/ActivitiesView.swift` | Activities tab | Discover → Explore nearby → Activities |
| `Views/Explore/ExploreMapOverlay.swift` | Explore tab | Discover → Explore nearby → Map |
| `Views/Explore/CategoryDetailView.swift` | Explore tab | Discover → Explore nearby → [Category] |
| `Views/Explore/NearYouSection.swift` | Explore tab | Discover → Explore nearby |
| `Views/Lunch/LunchView.swift` | Explore → Restaurants | Discover → Explore nearby → Restaurants |

---

## Chunk 1: Structural Migration (Steps 1–4)

> These steps rearrange existing views into the new 3-tab structure. No new features. Every step produces a buildable app.

---

### Task 1: Create DiscoverView shell and switch to 3 tabs

**Files:**
- Create: `ios-app/Znuni/Views/Discover/DiscoverView.swift`
- Create: `ios-app/Znuni/Views/Discover/DiscoverHeroBanner.swift`
- Modify: `ios-app/Znuni/App/AppState.swift` — change `AppTab` enum
- Modify: `ios-app/Znuni/App/ContentView.swift` — rewrite tab bar for 3 tabs

- [ ] **Step 1: Read current AppState.swift and ContentView.swift**

Read `ios-app/Znuni/App/AppState.swift` to find the `AppTab` enum definition and any `selectedTab` usage.
Read `ios-app/Znuni/App/ContentView.swift` to understand tab bar structure, navigation stacks, and how `WeekendTabView` and `ExploreNavigationStack` are defined.

- [ ] **Step 2: Add design tokens to Color+Theme.swift**

Add gradient color tokens FIRST so hero cards can reference them:

```swift
// In Color+Theme.swift, add:
static let sunshineGradientStart = Color(hex: "F5C842")
static let sunshineGradientEnd = Color(hex: "C4623A")
static let snowGradientStart = Color(hex: "B8D4E8")
static let snowGradientEnd = Color(hex: "4A7A9C")
static let eventsGradientStart = Color(hex: "3A7D5C")
static let eventsGradientEnd = Color(hex: "1A3A5C")
```

- [ ] **Step 2b: Update AppTab enum in AppState.swift**

Change `AppTab` from 5 cases to 3:

```swift
enum AppTab: String, CaseIterable {
    case today
    case discover
    case settings
}
```

Remove references to `.activities`, `.explore`, `.weekend`. Update any deep link handling that maps URL schemes to old tabs — `swissportal://events` and `swissportal://lunch` should map to `.discover`, `swissportal://weather` and `swissportal://weekend` should map to `.discover`.

- [ ] **Step 3: Create DiscoverHeroBanner.swift**

Create `ios-app/Znuni/Views/Discover/DiscoverHeroBanner.swift`. Navy gradient hero with "Discover" title in Playfair 30pt, city name in italic, skyline Canvas illustration. Follow the same pattern as `NewsHeroBanner.swift` and `ExploreHeroBanner.swift`:

```swift
import SwiftUI

struct DiscoverHeroBanner: View {
    let cityName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DISCOVER")
                .font(.znEyebrow)
                .foregroundColor(.white.opacity(0.35))

            Text("Discover")
                .font(.heroTitle)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.znNavy
                RadialGradient(
                    colors: [Color.znTerracotta.opacity(0.3), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 300
                )
                SkylineIllustration()
                    .opacity(0.09)
            }
        }
    }
}
```

- [ ] **Step 4: Create DiscoverView.swift (placeholder)**

Create `ios-app/Znuni/Views/Discover/DiscoverView.swift`. For now, a placeholder that shows the hero banner and a "Coming soon" body. This will be filled in over subsequent tasks.

```swift
import SwiftUI

struct DiscoverView: View {
    @Bindable var appState: AppState
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DiscoverHeroBanner(cityName: appState.selectedCity.name)

                VStack(spacing: 16) {
                    // Smart nudge slot (Task 7)
                    // Hero cards slot (Task 2-4)
                    // Explore nearby slot (Task 2-3)

                    Text("Discover content coming soon")
                        .font(.body)
                        .foregroundColor(.znMuted)
                        .padding(.top, 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .background(Color.znCream)
    }
}
```

- [ ] **Step 5: Rewrite ContentView.swift for 3 tabs**

**This is the biggest single change.** Replace the 5-tab structure with 3 tabs: Today, Discover, Settings.

**Important: Do the FULL tab rewrite in this step.** After this step, the old Explore/Activities/Weekend tabs no longer render. All navigation destinations are wired, even though the DiscoverView only has a placeholder body. This means Tasks 2-4 are purely about adding UI to DiscoverView, NOT about wiring navigation.

Key changes:

1. Remove `ExploreNavigationStack` private struct — replace with `DiscoverNavigationStack` that wraps `DiscoverView` in a `NavigationStack` with a `NavigationPath`.
2. Remove `WeekendTabView` usage and `WeekendSunshineView`/`WeekendSnowView` references.
3. Remove Activities tab rendering.
4. Keep `TodayNavigationStack` unchanged.
5. Update `ZnuniTabBar` to render 3 tabs with new icons:
   - Today: existing news grid icon
   - Discover: compass or mountain icon (reuse existing mountain from Weekend)
   - Settings: existing gear icon

The `DiscoverNavigationStack` must own or inject the view models that destination views need (SunshineViewModel, SnowViewModel, EventsViewModel, ActivitiesViewModel, LunchViewModel, ExploreViewModel, DealsViewModel). Check how `ExploreNavigationStack` and `WeekendTabView` currently create/hold these.

Wire ALL navigation destinations upfront using `.navigationDestination(for: DiscoverRoute.self)`:

```swift
enum DiscoverRoute: Hashable {
    case sunshine
    case snow
    case events
    case activities
    case restaurants
    case museums
    case parks
    case deals
    case map
}
```

```swift
enum DiscoverRoute: Hashable {
    case sunshine
    case snow
    case events
    case activities
    case restaurants
    case museums
    case parks
    case deals
    case map
}
```

**Note:** No `.category(ExploreCategory)` case — use the specific route cases above to avoid overlap. Also, `DealsView` does not currently exist as a standalone view. Either create a minimal `DealsView` (using `DealsViewModel` which exists) or route `.deals` to the existing `CategoryDetailView(category: .deals, ...)`. Check what `BrowseByTypeSection` currently does when tapping Deals.

Wire each route to the existing view (SunshineView, SnowView, EventsView, ActivitiesView, LunchView, CategoryDetailView, ExploreMapOverlay).

- [ ] **Step 6: Build and verify**

Run: `cd /Users/bq/Documents/Znuni/ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni -destination 'platform=iOS Simulator,id=1A941587-1C38-454E-9A8F-FB9F6D0D5601' build 2>&1 | grep -E "(BUILD|error:)"`

Expected: `BUILD SUCCEEDED`. The app should show 3 tabs. Today tab works as before. Discover shows placeholder. Settings works as before.

- [ ] **Step 7: Commit**

```bash
git add ios-app/Znuni/Views/Discover/ ios-app/Znuni/App/AppState.swift ios-app/Znuni/App/ContentView.swift
git commit -m "feat: restructure to 3 tabs (Today, Discover, Settings) with DiscoverView shell"
```

---

### Task 2: Wire sunshine and snow into Discover

**Files:**
- Modify: `ios-app/Znuni/Views/Discover/DiscoverView.swift` — add hero cards
- Create: `ios-app/Znuni/Views/Discover/SunshineHeroCard.swift`
- Create: `ios-app/Znuni/Views/Discover/SnowHeroCard.swift`
- Modify: `ios-app/Znuni/App/ContentView.swift` — add navigation destinations

- [ ] **Step 1: Create SunshineHeroCard.swift**

```swift
import SwiftUI

struct SunshineHeroCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("☀️ Where's the sun?")
                    .font(.cardHeadline)
                    .foregroundColor(.white)
                Text("Find the sunniest spot nearby")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: "F5C842"), Color(hex: "C4623A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }
}
```

- [ ] **Step 2: Create SnowHeroCard.swift**

Same pattern, cool gradient (light blue → navy). Only visible November–April:

```swift
import SwiftUI

struct SnowHeroCard: View {
    var isSnowSeason: Bool {
        let month = Calendar.current.component(.month, from: Date())
        return month >= 11 || month <= 4
    }

    var body: some View {
        if isSnowSeason {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("❄️ Where's the snow?")
                        .font(.cardHeadline)
                        .foregroundColor(.white)
                    Text("Fresh powder & ski conditions")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "B8D4E8"), Color(hex: "4A7A9C")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        }
    }
}
```

- [ ] **Step 3: Add hero cards to DiscoverView**

Replace the placeholder in `DiscoverView.swift` with the hero cards section. Each card is a `Button` that appends a `DiscoverRoute` to the navigation path:

```swift
// Inside DiscoverView ScrollView VStack, after hero banner:
VStack(spacing: 12) {
    Button { path.append(DiscoverRoute.sunshine) } label: {
        SunshineHeroCard()
    }

    Button { path.append(DiscoverRoute.snow) } label: {
        SnowHeroCard()
    }
}
.padding(.horizontal, 16)
.padding(.top, 16)
```

- [ ] **Step 4: Wire navigation destinations in ContentView**

In `DiscoverNavigationStack`, add `.navigationDestination(for: DiscoverRoute.self)` that switches on the route and returns the appropriate view. For `.sunshine` → `SunshineView(viewModel: sunshineVM)`. For `.snow` → `SnowView(viewModel: snowVM)`.

Check existing `SunshineView` and `SnowView` initializers to match required parameters. The view models (`SunshineViewModel`, `SnowViewModel`) need to be created and held by either `DiscoverNavigationStack` or injected via environment.

- [ ] **Step 5: Build and verify**

Run: `xcodebuild ...` — Expected: BUILD SUCCEEDED. Tapping sunshine hero card pushes SunshineView. Tapping snow hero card pushes SnowView (if in season).

- [ ] **Step 6: Commit**

```bash
git add ios-app/Znuni/Views/Discover/
git commit -m "feat: add sunshine and snow hero cards to Discover tab"
```

---

### Task 3: Wire events and Explore nearby into Discover

**Files:**
- Create: `ios-app/Znuni/Views/Discover/EventsHeroCard.swift`
- Create: `ios-app/Znuni/Views/Discover/ExploreNearbySection.swift`
- Modify: `ios-app/Znuni/Views/Discover/DiscoverView.swift` — add events hero + browse grid
- Modify: `ios-app/Znuni/App/ContentView.swift` — add navigation destinations for events, activities, categories, lunch, map

- [ ] **Step 1: Create EventsHeroCard.swift**

Green → navy gradient. Shows upcoming event count badge.

```swift
import SwiftUI

struct EventsHeroCard: View {
    let upcomingCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("📅 What's happening")
                    .font(.cardHeadline)
                    .foregroundColor(.white)
                Text("Events, markets & festivals")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            if upcomingCount > 0 {
                Text("\(upcomingCount) this week")
                    .font(.znLabel)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: "3A7D5C"), Color(hex: "1A3A5C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }
}
```

- [ ] **Step 2: Create ExploreNearbySection.swift**

Reuses the browse-by-type grid pattern from `BrowseByTypeSection.swift`. 2×2 grid of category tiles + map button + surprise me button.

```swift
import SwiftUI

struct ExploreNearbySection: View {
    @Binding var path: NavigationPath
    let activityCount: Int
    let museumCount: Int
    let parkCount: Int
    let restaurantCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore nearby")
                .font(.sectionHeadline)
                .foregroundColor(.znInk)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                browseTile("Activities", icon: "star.fill", count: activityCount, route: .activities)
                browseTile("Museums", icon: "building.columns.fill", count: museumCount, route: .museums)
                browseTile("Parks", icon: "leaf.fill", count: parkCount, route: .parks)
                browseTile("Restaurants", icon: "fork.knife", count: restaurantCount, route: .restaurants)
            }

            HStack(spacing: 12) {
                Button { path.append(DiscoverRoute.map) } label: {
                    Label("Map", systemImage: "map")
                        .font(.znLabel)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func browseTile(_ title: String, icon: String, count: Int, route: DiscoverRoute) -> some View {
        Button { path.append(route) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.znNavy)
                Text(title)
                    .font(.cardHeadline)
                    .foregroundColor(.znInk)
                Text("\(count) places")
                    .font(.caption)
                    .foregroundColor(.znMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.znSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(Color.znBorder, lineWidth: 1)
            )
        }
    }
}
```

- [ ] **Step 3: Add events hero + explore nearby to DiscoverView**

Update `DiscoverView.swift` to include all three hero cards and the browse grid. The events hero card needs an upcoming event count — get this from `ExploreViewModel` or compute inline from the events data.

- [ ] **Step 4: Wire navigation destinations**

In `DiscoverNavigationStack`, add destinations:
- `.events` → `EventsView(viewModel: eventsVM)`
- `.activities` → `ActivitiesView(viewModel: activitiesVM)`
- `.restaurants` → `LunchView(viewModel: lunchVM)`
- `.museums` → `CategoryDetailView(category: .museums, ...)`
- `.parks` → `CategoryDetailView(category: .parks, ...)`
- `.map` → `ExploreMapOverlay(...)`

Check each view's initializer signature and match required parameters.

- [ ] **Step 5: Update event "Add to your plan" CTA**

In `ios-app/Znuni/Views/Events/EventCard.swift` (line ~38-40), the CTA text is "Add to your plan" (not "Add to plan"). It's gated by `event.isPlannable && event.overlaps(with: Date())` — meaning it only shows for today's events.

Changes needed:
1. Rename button text to "Plan around this →"
2. Remove the `isToday` / `overlaps(with: Date())` gate — the CTA should work for events on ANY date
3. Wire the full navigation flow: on tap, open `AnchorFormSheet` pre-filled with event, then on save, set `selectedPlanDay = .specific(event.startDate)` and switch to Today tab

Same changes in `ios-app/Znuni/Views/Events/DayDetailView.swift` (line ~207-217), which has the same CTA with the same `isToday` gate.

- [ ] **Step 6: Build and verify**

Run: `xcodebuild ...` — Expected: BUILD SUCCEEDED. Discover shows 3 hero cards (sunshine, snow, events) + 2×2 browse grid. Each pushes to the correct existing view.

- [ ] **Step 7: Commit**

```bash
git add ios-app/Znuni/Views/Discover/ ios-app/Znuni/Views/Events/ ios-app/Znuni/App/ContentView.swift
git commit -m "feat: wire events, activities, and explore nearby into Discover tab"
```

---

### Task 4: Delete Weekend tab and clean up old tabs

**Files:**
- Delete: `ios-app/Znuni/Views/Weekend/WeekendView.swift`
- Delete: `ios-app/Znuni/Views/Weekend/WeekendDayCard.swift`
- Delete: `ios-app/Znuni/ViewModels/WeekendViewModel.swift`
- Modify: `ios-app/Znuni/App/ContentView.swift` — remove any remaining old tab references
- Modify: `ios-app/Znuni/Views/Discover/DiscoverView.swift` — add Surprise Me button

- [ ] **Step 1: Read WeekendView.swift to identify dependencies**

Read `ios-app/Znuni/Views/Weekend/WeekendView.swift` to check if any other file imports or references it. Search for `WeekendView` across the codebase.

- [ ] **Step 2: Delete Weekend planner files**

```bash
rm ios-app/Znuni/Views/Weekend/WeekendView.swift
rm ios-app/Znuni/Views/Weekend/WeekendDayCard.swift
rm ios-app/Znuni/ViewModels/WeekendViewModel.swift
```

Keep `WeekendResponse.swift` (model used by sunshine/weather). Keep `WeekendViewModel` references in `TodayViewModel` if any exist for the `composeWeekend()` function — that function stays but is now only called from the Today tab date picker when Saturday/Sunday is selected.

- [ ] **Step 3: Remove old ExploreView.swift and ExploreHeroBanner.swift**

These are replaced by DiscoverView and DiscoverHeroBanner. Check for any references first.

```bash
rm ios-app/Znuni/Views/Explore/ExploreView.swift
rm ios-app/Znuni/Views/Explore/ExploreHeroBanner.swift
```

Keep: `ExploreMapOverlay.swift`, `CategoryDetailView.swift`, `NearYouSection.swift`, `BrowseByTypeSection.swift` — these are reused in Discover.

- [ ] **Step 4: Remove old BrowseByTypeSection.swift if replaced**

If `ExploreNearbySection.swift` (created in Task 3) fully replaces `BrowseByTypeSection.swift`, delete the old one. If the old one has Canvas illustrations we want to keep, extract them into `ExploreNearbySection` first.

- [ ] **Step 5: Clean up ContentView.swift**

Remove any dead code references to `ExploreNavigationStack`, `WeekendTabView`, old tab cases. Verify the tab bar only shows 3 tabs with correct icons and labels.

- [ ] **Step 6: Add Surprise Me to Discover**

Move the "Surprise me!" button from ActivitiesView into the Discover → Explore nearby section (below the browse grid). The `SurpriseMeSheet` component stays unchanged — it just gets triggered from a different location.

- [ ] **Step 7: Build and verify**

Run: `xcodebuild ...` — Expected: BUILD SUCCEEDED with no warnings about missing files. App has exactly 3 tabs. All Discover navigation works. No dead code.

- [ ] **Step 8: Commit**

```bash
git add ios-app/Znuni/Views/Discover/ ios-app/Znuni/App/ContentView.swift
git rm ios-app/Znuni/Views/Weekend/WeekendView.swift ios-app/Znuni/Views/Weekend/WeekendDayCard.swift ios-app/Znuni/ViewModels/WeekendViewModel.swift ios-app/Znuni/Views/Explore/ExploreView.swift ios-app/Znuni/Views/Explore/ExploreHeroBanner.swift
git commit -m "feat: remove old Weekend/Explore/Activities tabs, complete 3-tab migration"
```

---

## Chunk 2: Date Picker & City Context (Steps 5–6)

> These steps add new capabilities to the planner: any-date planning and multi-city support.

---

### Task 5: Date picker on Today tab

**Files:**
- Create: `ios-app/Znuni/Views/Today/DatePickerRow.swift`
- Create: `ios-app/Znuni/Views/Today/DatePickerSheet.swift`
- Modify: `ios-app/Znuni/Models/DayAgenda.swift` — extend `PlanDay` enum (lives here, NOT in Date+Helpers)
- Modify: `ios-app/Znuni/ViewModels/TodayViewModel.swift` — wire date selection, remove `composeWeekend()` and `isWeekendMode`
- Modify: `ios-app/Znuni/Views/Today/TodayView.swift` — add date picker to Plan header
- Modify: `ios-app/Znuni/Views/Today/TodayHeroBanner.swift` — add date picker row slot

- [ ] **Step 1: Read current PlanDay enum**

Read `ios-app/Znuni/Models/DayAgenda.swift` (PlanDay is defined here, starting ~line 6). Note current cases (`today`, `tomorrow`, `saturday`, `sunday`), the `date()` function, and `CaseIterable` conformance.

- [ ] **Step 2: Extend PlanDay enum**

Add `.specific(Date)` case. **Remove `CaseIterable` conformance** (associated values break it). Search the codebase for `PlanDay.allCases` and update any usage — the `availablePlanDays` computed property in `TodayViewModel` needs to return an explicit array instead.

Update the `date()` function and `isoDate` to handle the new case:

```swift
enum PlanDay: Equatable, Hashable {  // removed CaseIterable
    case today
    case tomorrow
    case saturday
    case sunday
    case specific(Date)

    func date() -> Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .today: return now
        case .tomorrow:
            return cal.date(byAdding: .day, value: 1, to: now) ?? now
        case .saturday:
            return PlanDay.nextWeekendDates().saturday
        case .sunday:
            return PlanDay.nextWeekendDates().sunday
        case .specific(let d):
            return cal.startOfDay(for: d)
        }
    }
}
```

Also add `.specific` handling to `isoDate` and any other computed properties on `PlanDay`.

- [ ] **Step 2b: Remove composeWeekend() and isWeekendMode from TodayViewModel**

The Weekend Planner is eliminated. `composeWeekend()` (which composed Saturday+Sunday in parallel) is replaced by the date picker selecting Saturday or Sunday individually, each calling `composeAgendaForDate()`. Remove `composeWeekend()`, `isWeekendMode`, and `_weekendWeather` from `TodayViewModel`. Update any callers.

- [ ] **Step 3: Create DatePickerRow.swift**

Horizontal pill row below the hero title:

```swift
import SwiftUI

struct DatePickerRow: View {
    @Binding var selectedDay: PlanDay
    @State private var showDatePicker = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                datePill("Today", day: .today)
                datePill("Tomorrow", day: .tomorrow)
                datePill(saturdayLabel, day: .saturday)
                datePill(sundayLabel, day: .sunday)

                // "Pick date" opens calendar sheet
                Button {
                    showDatePicker = true
                } label: {
                    Text("Pick date →")
                        .font(.znLabel)
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDay: $selectedDay)
                .presentationDetents([.medium])
        }
    }

    private func datePill(_ label: String, day: PlanDay) -> some View {
        Button {
            selectedDay = day
        } label: {
            Text(label)
                .font(.znLabel)
                .foregroundColor(selectedDay == day ? .znNavy : .white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selectedDay == day ? .white : .white.opacity(0.08))
                .clipShape(Capsule())
        }
    }

    private var saturdayLabel: String {
        let day = PlanDay.saturday.date
        let num = Calendar.current.component(.day, from: day)
        return "Sat \(num)"
    }

    private var sundayLabel: String {
        let day = PlanDay.sunday.date
        let num = Calendar.current.component(.day, from: day)
        return "Sun \(num)"
    }
}
```

- [ ] **Step 4: Create DatePickerSheet.swift**

Calendar sheet limited to 14 days from today:

```swift
import SwiftUI

struct DatePickerSheet: View {
    @Binding var selectedDay: PlanDay
    @Environment(\.dismiss) private var dismiss
    @State private var pickedDate = Date()

    var body: some View {
        NavigationStack {
            DatePicker(
                "Pick a date",
                selection: $pickedDate,
                in: Date()...Calendar.current.date(byAdding: .day, value: 14, to: Date())!,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Pick a date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedDay = .specific(pickedDate)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 5: Wire into TodayViewModel**

In `TodayViewModel.swift`:
1. Remove the hardcoded `availablePlanDays = [.today, .tomorrow]` if it exists.
2. When `selectedPlanDay` changes, call `composeAgendaForSelectedDay()`. This function already exists and handles date-based composition.
3. The `.specific(Date)` case should work with the existing `composeAgendaForDate()` since it already accepts a `planDate: Date` parameter.

- [ ] **Step 6: Add DatePickerRow to TodayHeroBanner / TodayView**

In `TodayView.swift` or `TodayHeroBanner.swift`, add the `DatePickerRow` below the weather row in Plan mode (not News mode). Check the existing hero structure to find the right insertion point.

- [ ] **Step 7: Build and verify**

Expected: BUILD SUCCEEDED. In Plan mode, date pills appear. Tapping Saturday composes for Saturday. "Pick date →" opens calendar sheet. Selecting a date composes for that date.

- [ ] **Step 8: Commit**

```bash
git add ios-app/Znuni/Views/Today/DatePickerRow.swift ios-app/Znuni/Views/Today/DatePickerSheet.swift ios-app/Znuni/Extensions/Date+Helpers.swift ios-app/Znuni/ViewModels/TodayViewModel.swift ios-app/Znuni/Views/Today/TodayView.swift ios-app/Znuni/Views/Today/TodayHeroBanner.swift
git commit -m "feat: add date picker to Today tab — plan any date within 14 days"
```

---

### Task 6: City context and planner CTA on city cards

**Files:**
- Create: `ios-app/Znuni/Models/PlanningCity.swift`
- Modify: `ios-app/Znuni/ViewModels/TodayViewModel.swift` — add `planningCity`, wire into composition
- Modify: `ios-app/Znuni/Views/Today/TodayHeroBanner.swift` — "Today in {city}" with gradient
- Verify: `ios-app/Znuni/Services/AgendaCache.swift` — already accepts `city` parameter (defaults to "zurich"). No struct change needed — just pass `planningCity.id` at call sites.
- Modify: `ios-app/Znuni/Views/Sunshine/SunshineCard.swift` — add "Plan a day in {city} →" CTA
- Modify: `ios-app/Znuni/Views/Snow/SnowCard.swift` — add "Plan a ski day →" CTA

- [ ] **Step 1: Create PlanningCity.swift**

```swift
import Foundation

struct PlanningCity: Codable, Equatable, Hashable {
    let id: String
    let name: String

    static let zurich = PlanningCity(id: "zurich", name: "Zürich")
    static let basel = PlanningCity(id: "basel", name: "Basel")
    static let bern = PlanningCity(id: "bern", name: "Bern")
    static let geneva = PlanningCity(id: "geneva", name: "Geneva")
    static let lausanne = PlanningCity(id: "lausanne", name: "Lausanne")
    static let luzern = PlanningCity(id: "luzern", name: "Luzern")
    static let winterthur = PlanningCity(id: "winterthur", name: "Winterthur")

    static let coveredCities: [PlanningCity] = [
        .zurich, .basel, .bern, .geneva, .lausanne, .luzern, .winterthur
    ]

    static func isCovered(_ cityId: String) -> Bool {
        coveredCities.contains { $0.id == cityId }
    }
}
```

- [ ] **Step 2: Add planningCity to TodayViewModel**

In `TodayViewModel.swift`:

```swift
@Published var planningCity: PlanningCity = .zurich
```

When `planningCity` changes, invalidate `AgendaCache` and recompose. In `composeAgendaForDate()`, filter the venue pool by `planningCity.id` — the `buildScoredPool()` function already receives activities/restaurants, so filter them before passing:

```swift
let cityActivities = activities.filter { $0.city == planningCity.id || $0.city == nil }
let cityRestaurants = restaurants.filter { /* match by city */ }
```

Check exact field names on Activity and LunchSpot models for city filtering.

- [ ] **Step 3: Verify AgendaCache city parameter**

`AgendaCache` already accepts a `city` parameter (defaults to "zurich") in both `get()` and `store()`. No structural change needed. Just ensure all call sites in `TodayViewModel.composeAgendaForDate()` pass `planningCity.id` instead of relying on the default. Search for `AgendaCache.shared.get(` and `AgendaCache.shared.store(` to find all call sites.

- [ ] **Step 4: Update TodayHeroBanner**

Change the title from hardcoded "Today in *Zürich*" to "Today in *{planningCity.name}*". If `planningCity != .zurich`, optionally use a warm terracotta gradient instead of the standard navy.

- [ ] **Step 5: Add "Plan a day in {city}" CTA to SunshineCard**

Read `ios-app/Znuni/Views/Sunshine/SunshineCard.swift`. In the expanded state, add a conditional CTA:

```swift
if PlanningCity.isCovered(destination.id) {
    Button {
        // Navigate to Today tab with city + date context
        // This requires access to TodayViewModel and AppState
        // Pass via environment or closure
    } label: {
        Text("Plan a day in \(destination.name) →")
            .font(.znLabel)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.znTerracotta)
            .clipShape(Capsule())
    }
}
```

The navigation action needs to: set `todayViewModel.planningCity`, set `todayViewModel.selectedPlanDay` to the sunshine forecast date, and switch `appState.selectedTab = .today`. Pass these via closures or environment objects.

- [ ] **Step 6: Add similar CTA to SnowCard**

Same pattern for `ios-app/Znuni/Views/Snow/SnowCard.swift`.

- [ ] **Step 7: Build and verify**

Expected: BUILD SUCCEEDED. Sunshine card for Zürich/Basel/etc shows "Plan a day here" CTA. Tapping switches to Today tab with that city's name in the header.

- [ ] **Step 8: Commit**

```bash
git add ios-app/Znuni/Models/PlanningCity.swift ios-app/Znuni/ViewModels/TodayViewModel.swift ios-app/Znuni/Views/Today/TodayHeroBanner.swift ios-app/Znuni/Services/AgendaCache.swift ios-app/Znuni/Views/Sunshine/SunshineCard.swift ios-app/Znuni/Views/Snow/SnowCard.swift
git commit -m "feat: add city context to planner + 'Plan a day here' CTA on sunshine/snow cards"
```

---

## Chunk 3: Smart Nudge & Proximity Scoring (Step 7)

> New intelligence: proactive nudges on Discover and location-aware slot filling.

---

### Task 7: Smart nudge engine and card

**Files:**
- Create: `ios-app/Znuni/Services/NudgeEngine.swift`
- Create: `ios-app/Znuni/Views/Discover/SmartNudgeCard.swift`
- Modify: `ios-app/Znuni/Views/Discover/DiscoverView.swift` — add nudge at top of scroll

- [ ] **Step 1: Create NudgeEngine.swift**

```swift
import Foundation

enum NudgeType: Equatable {
    case sunshineEscape(cityName: String, cityId: String, temp: Int, sunHours: Double, date: Date)
    case upcomingEvent(event: CityEvent)
    case snowAlert(resortName: String, resortId: String, freshCm: Int, travelTime: String)
}

struct SmartNudge: Identifiable {
    let id = UUID()
    let type: NudgeType
    let createdDate: Date
    var dismissed: Bool = false
}

class NudgeEngine {
    /// Evaluate conditions and return the highest-priority nudge, or nil.
    func evaluate(
        currentCityWeather: Weather?,
        sunshineData: SunshineResponse?,
        snowData: SnowResponse?,
        events: [CityEvent],
        existingAnchors: [AnchorEvent]
    ) -> SmartNudge? {
        // Priority 1: Sunshine escape
        if let nudge = evaluateSunshineEscape(weather: currentCityWeather, sunshine: sunshineData) {
            return nudge
        }

        // Priority 2: Upcoming plannable event (within 3 weeks, no anchor on that date)
        if let nudge = evaluateUpcomingEvent(events: events, anchors: existingAnchors) {
            return nudge
        }

        // Priority 3: Snow alert (Nov–Apr, >20cm fresh)
        if let nudge = evaluateSnowAlert(snow: snowData) {
            return nudge
        }

        return nil
    }

    private func evaluateSunshineEscape(weather: Weather?, sunshine: SunshineResponse?) -> SmartNudge? {
        guard let weather, let sunshine else { return nil }
        // Current city is poor weather (overcast/rain, <12°C)
        guard weather.temperature < 12, weather.weatherCode >= 45 else { return nil }
        // Find ANY city with >6h sunshine and >16°C (not gated by isCovered —
        // the nudge recommends the escape destination, the "Plan a day" CTA
        // on the sunshine card is what's gated by isCovered)
        guard let best = sunshine.destinations.first(where: {
            $0.sunshineHoursTotal > 6 &&
            ($0.forecast.first?.tempMax ?? 0) > 16
        }) else { return nil }

        let forecastDate = sunshine.weekendDates.saturday // or best date
        return SmartNudge(
            type: .sunshineEscape(
                cityName: best.name,
                cityId: best.id,
                temp: Int(best.forecast.first?.tempMax ?? 0),
                sunHours: best.sunshineHoursTotal,
                date: ISO8601DateFormatter().date(from: forecastDate) ?? Date()
            ),
            createdDate: Date()
        )
    }

    private func evaluateUpcomingEvent(events: [CityEvent], anchors: [AnchorEvent]) -> SmartNudge? {
        let threeWeeksOut = Calendar.current.date(byAdding: .weekOfYear, value: 3, to: Date())!
        let anchorDates = Set(anchors.map { Calendar.current.startOfDay(for: $0.startTime) })

        guard let event = events.first(where: { event in
            guard let startDate = ISO8601DateFormatter().date(from: event.startDate) else { return false }
            return startDate > Date() && startDate < threeWeeksOut &&
                   !anchorDates.contains(Calendar.current.startOfDay(for: startDate))
        }) else { return nil }

        return SmartNudge(type: .upcomingEvent(event: event), createdDate: Date())
    }

    private func evaluateSnowAlert(snow: SnowResponse?) -> SmartNudge? {
        let month = Calendar.current.component(.month, from: Date())
        guard month >= 11 || month <= 4 else { return nil }
        guard let snow else { return nil }
        guard let top = snow.destinations.first, top.snowfallWeekTotal > 20 else { return nil }

        return SmartNudge(
            type: .snowAlert(
                resortName: top.name,
                resortId: top.id,
                freshCm: Int(top.snowfallWeekTotal),
                travelTime: "\(top.driveMinutes / 60)h \(top.driveMinutes % 60)m"
            ),
            createdDate: Date()
        )
    }
}
```

- [ ] **Step 2: Create SmartNudgeCard.swift**

Renders the nudge with appropriate styling based on type. Tapping the CTA navigates appropriately (sunshine escape → sunshine ranking or Today tab, event → anchor form, snow → snow view).

- [ ] **Step 3: Wire nudge into DiscoverView**

Add `NudgeEngine` evaluation on appear. Show `SmartNudgeCard` at top of scroll if a nudge is available.

- [ ] **Step 4: Build and verify**

Expected: BUILD SUCCEEDED. Smart nudge appears when conditions are met (may need to mock weather data to test).

- [ ] **Step 5: Commit**

```bash
git add ios-app/Znuni/Services/NudgeEngine.swift ios-app/Znuni/Views/Discover/SmartNudgeCard.swift ios-app/Znuni/Views/Discover/DiscoverView.swift
git commit -m "feat: add smart nudge engine and contextual cards to Discover tab"
```

---

### Task 8: Anchor location and proximity scoring

**Files:**
- Modify: `ios-app/Znuni/Models/DayAnchor.swift` — add address, lat, lon fields
- Modify: `ios-app/Znuni/Views/Today/AnchorFormSheet.swift` — add Step 6 (address)
- Modify: `ios-app/Znuni/Services/FreshnessScorer.swift` — add `applyProximityBias()`
- Modify: `ios-app/Znuni/Services/AgendaComposer.swift` — add proximity rule to prompt

- [ ] **Step 1: Read current AnchorEvent model**

Read `ios-app/Znuni/Models/DayAnchor.swift` to see the current fields and Codable conformance.

- [ ] **Step 2: Add location fields to AnchorEvent**

```swift
// Add to AnchorEvent struct:
var address: String?
var lat: Double?
var lon: Double?

var hasLocation: Bool {
    lat != nil && lon != nil
}
```

Ensure Codable conformance handles the new optional fields (should work automatically with struct synthesis).

- [ ] **Step 3: Add address step and pre-fill support to AnchorFormSheet**

Read `ios-app/Znuni/Views/Today/AnchorFormSheet.swift` to understand the current 5-step flow.

**Two changes:**

**A) Pre-fill support** — Add optional `prefill` parameter to `AnchorFormSheet` init:
```swift
struct AnchorPrefill {
    var title: String?
    var category: AnchorCategory?
    var lat: Double?
    var lon: Double?
    var date: Date?
}
```
When provided, pre-populate the form fields. This enables the "Plan around this →" flow from activity/lunch/event cards.

**B) Step 6 — Address** — Add as an optional address text field with geocoding via `CLGeocoder`:

```swift
// Step 6: Where exactly? (optional)
TextField("Address (optional)", text: $address)
    .onChange(of: address) { _, newValue in
        // Debounced geocode
        geocodeAddress(newValue)
    }
```

When the user enters an address, geocode it to lat/lon using `CLGeocoder().geocodeAddressString()`. If the anchor came from EventKit and the calendar event has a `structuredLocation`, extract lat/lon directly.

- [ ] **Step 4: Add applyProximityBias to FreshnessScorer**

Read `ios-app/Znuni/Services/FreshnessScorer.swift`. Add a function that biases the venue pool for gaps adjacent to anchors with known locations:

```swift
static func applyProximityBias(
    venues: [ScoredVenue],
    adjacentAnchor: AnchorEvent?,
    maxTravelMinutes: Int = 20
) -> [ScoredVenue] {
    guard let anchor = adjacentAnchor, anchor.hasLocation,
          let anchorLat = anchor.lat, let anchorLon = anchor.lon else {
        return venues
    }

    return venues.map { scored in
        let distance = haversineDistance(
            lat1: anchorLat, lon1: anchorLon,
            lat2: scored.venue.lat, lon2: scored.venue.lon
        )
        let estimatedMinutes = distance / 0.5 // ~30km/h average
        let proximityMultiplier: Double
        if estimatedMinutes <= Double(maxTravelMinutes) {
            proximityMultiplier = 1.0
        } else {
            proximityMultiplier = max(0.2, 1.0 - (estimatedMinutes - Double(maxTravelMinutes)) / 30.0)
        }
        var adjusted = scored
        adjusted.score *= proximityMultiplier
        return adjusted
    }
    .sorted { $0.score > $1.score }
}
```

Call this in `buildScoredPool()` for gaps that have a `precedingAnchor` or `followingAnchor` with a location.

- [ ] **Step 5: Add proximity rule to AgendaComposer prompt**

Read `ios-app/Znuni/Services/AgendaComposer.swift`. Add rule 12 to the system prompt:

```
12. If an anchor has a location, slots immediately before or after it should be
    geographically close (within 20 minutes). The venue pool is pre-sorted by proximity
    for these gaps — prefer venues appearing earlier in the list.
```

- [ ] **Step 6: Build and verify**

Expected: BUILD SUCCEEDED. Anchor form shows optional address step. Proximity bias applied when anchor has location.

- [ ] **Step 7: Commit**

```bash
git add ios-app/Znuni/Models/DayAnchor.swift ios-app/Znuni/Views/Today/AnchorFormSheet.swift ios-app/Znuni/Services/FreshnessScorer.swift ios-app/Znuni/Services/AgendaComposer.swift
git commit -m "feat: add anchor location + proximity scoring for adjacent slots"
```

---

### Task 9: "Plan around this" universal CTA on activity and lunch cards

**Files:**
- Modify: `ios-app/Znuni/Views/Activities/ActivityCard.swift` — add "Plan around this →"
- Modify: `ios-app/Znuni/Views/Lunch/LunchCard.swift` — add "Plan around this →"

- [ ] **Step 1: Read ActivityCard expanded state**

Read `ios-app/Znuni/Views/Activities/ActivityCard.swift` to find where the expanded content ends (action buttons section).

- [ ] **Step 2: Add CTA to ActivityCard**

Below the existing action buttons in the expanded state, add:

```swift
Button {
    onPlanAroundThis?(activity)
} label: {
    Text("Plan around this →")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.znTerracotta)
}
```

Add `var onPlanAroundThis: ((Activity) -> Void)?` to the ActivityCard initializer. The parent view wires this to open `AnchorFormSheet` pre-filled with the activity name, category `.activity`, and coordinates.

- [ ] **Step 3: Add CTA to LunchCard**

Same pattern for `ios-app/Znuni/Views/Lunch/LunchCard.swift`.

- [ ] **Step 4: Wire navigation from Discover context**

When "Plan around this →" is tapped from within Discover:
1. Present `AnchorFormSheet` as a sheet, pre-filled with venue data
2. On save: create anchor, set `appState.selectedTab = .today`
3. The anchor triggers recomposition via `AnchorStore.didChangeNotification`

- [ ] **Step 5: Build and verify**

Expected: BUILD SUCCEEDED. Expanded activity/lunch cards show "Plan around this →" link.

- [ ] **Step 6: Commit**

```bash
git add ios-app/Znuni/Views/Activities/ActivityCard.swift ios-app/Znuni/Views/Lunch/LunchCard.swift
git commit -m "feat: add 'Plan around this' universal CTA to activity and lunch cards"
```

---

### Task 10: Final verification and polish

**Files:** None new — this is a verification pass.

- [ ] **Step 1: Build final verification**

Run full build. Install on simulator. Manually verify:
- 3 tabs render correctly
- Discover: hero cards navigate to sunshine/snow/events
- Discover: browse grid navigates to activities/museums/parks/restaurants
- Today: date picker works (today/tomorrow/sat/sun/pick date)
- Today: city context shows correct city name when navigating from sunshine
- Smart nudge appears when conditions are met
- "Plan around this" works on activity/lunch/event cards

- [ ] **Step 3: Commit**

```bash
git add ios-app/Znuni/Extensions/Color+Theme.swift
git commit -m "feat: add design tokens for Discover tab gradients"
```

---

## Handoff Notes

**Do here (Claude Code):** Tasks 1–4 (structural migration). These are multi-file refactoring tasks that benefit from parallel agents and CLI builds. No visual iteration needed — just wiring navigation.

**Switch to Xcode:** Tasks 5–10 (date picker, city context, smart nudge, proximity, polish). These need SwiftUI previews, simulator interaction, and visual tuning. The date picker and smart nudge card in particular need visual iteration.

**Key risk:** Task 1 (ContentView rewrite) is the largest single change. Read the current ContentView carefully before modifying — it has `TodayNavigationStack`, `ExploreNavigationStack`, and `WeekendTabView` as private structs with view model ownership. The new `DiscoverNavigationStack` needs to own or share the view models that sunshine/snow/events/activities/lunch views need.

**Testing:** After each task, run `xcodebuild` and verify BUILD SUCCEEDED. After Task 4 (complete structural migration), do a full simulator walkthrough of all Discover navigation paths before moving to new features.
