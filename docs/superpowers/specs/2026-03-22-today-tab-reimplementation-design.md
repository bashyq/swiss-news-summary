# Today Tab Reimplementation — Design Spec

> **Date:** 2026-03-22
> **Status:** Draft
> **Branch:** TBD (new branch off master)
> **Mockups:** `.superpowers/brainstorm/88117-1774175237/today-complete.html`

---

## 1. Problem Statement

The current Plan mode in the Today tab has 7+ open bugs stemming from a 2,047-line god ViewModel (`TodayViewModel`) that owns data loading, agenda composition, calendar sync, execution mode, multi-day state, and slot editing. State synchronization failures cascade unpredictably — one piece of state changes but dependent pieces don't update because triggers are scattered across `.onAppear`, `.onChange`, and notification observers.

The interaction model is also confused: compose, swap tray, rebuild, calendar swipe, and lock/unlock are five separate patterns for what is conceptually one interaction.

## 2. Goals

1. **Clean reimplementation** of the Today tab with a simpler, more predictable architecture
2. **Unified interaction model** based on a "card dealing" metaphor: deal → hold → discard → redeal
3. **Fix all 7 open bugs** by eliminating the root cause (entangled state management)
4. **Separate Plan from News** into distinct tabs

### Non-Goals

- Execution mode (real-time day progress) — deferred
- Family session config / kid count — cut
- User-facing vibe/archetype selector — cut (weather-based auto-selection stays in template fallback)
- Rewriting working services (GapAnalysisEngine, AgendaComposer, TemplateEngine, CalendarService) — keep as-is unless bugs surface

## 3. Tab Structure

**4 tabs:** News, Today, Discover, Settings

- **News** — existing news feed (currently the "Today" tab's news sub-view, extracted to its own tab)
- **Today** — the plan tab (this spec)
- **Discover** — existing discover tab (unchanged)
- **Settings** — existing settings tab (unchanged)

### Tab Bar Icons

| Tab | Icon | Style |
|-----|------|-------|
| News | Folded newspaper with text lines | Stroke when inactive, stroke when active |
| Today | Rounded square with list lines | Stroke when inactive, first square filled when active |
| Discover | Mountain landscape | Stroke/filled per existing pattern |
| Settings | Gear | Stroke/filled per existing pattern |

## 4. Interaction Model — "Card Dealing"

The entire Plan mode follows one repeatable loop:

```
Plan my day → Cards are dealt → Review → Hold (lock) / Discard (unlock) → Redeal → Save
```

### Concepts

| Concept | Meaning |
|---------|---------|
| **Deal** | Initial plan composition — engine fills time slots with venue suggestions |
| **Hold (Lock)** | Lock a slot — it survives redeals |
| **Discard (Unlock)** | Unlock a slot — it gets replaced on next redeal |
| **Redeal** | Recompose all unlocked slots as a batch (engine optimizes them together) |
| **Save** | Write all slots to iOS Calendar as events, auto-lock everything |
| **Decks** | Source pools: Calendar events, Activities, Restaurants |

### What This Replaces

The old separate interactions (compose, swap tray, rebuild, calendar swipe, lock/unlock) are all subsumed by this single loop. There is no swap tray — you unlock and redeal.

## 5. User Stories

### Core Flow

**US-1: Open Plan mode (empty, no calendar events)**
> User opens Today tab. Sees date strip, weather summary, and "Plan my day" CTA. No auto-composition.

**US-2: Open Plan mode (calendar events exist)**
> User opens Today tab for a day with calendar events. Events appear as locked cards on the timeline. CTA says "Fill the gaps" with subtitle showing which slots will be filled (e.g. "Morning · Lunch · Afternoon · Dinner").

**US-3: Compose from scratch**
> User taps "Plan my day". Engine composes a day based on weather, time of day, opening hours, and available venues. Cards deal in with a brief sequential animation.

**US-4: Compose around calendar**
> User taps "Fill the gaps". Calendar events stay as locked cards. Engine fills gaps around them. Two-beat animation: calendar cards appear first, then gap-fill cards deal in around them.

**US-5: Select a future date**
> User taps a date in the 14-day scrollable strip. UI updates: hero title changes (e.g. "Plan your Sunday"), weather updates to forecast for that day, calendar events for that day are fetched. CTA shown for the new date.

**US-6: Select a date beyond 14 days**
> User taps calendar icon at end of date strip. Date picker sheet appears. Selected date becomes active.

### Card Interactions

**US-7: Expand a card for details**
> User taps a card. It expands: photo slides to top (full-width), 2×2 metadata grid (address, hours, distance, price), reason text, tags, and action buttons (Directions, Website). Stay-at-home cards expand without photo.

**US-8: Lock a card via ⋯ menu**
> User taps ⋯ on a dealt card → "Lock this slot". Card gets 🔒 Locked badge. Survives redeals.

**US-9: Unlock a card via ⋯ menu**
> User taps ⋯ on a locked card → "Unlock". Lock badge removed. Card will be replaced on next redeal.

**US-10: Replace with custom entry**
> User taps ⋯ → "Replace with my own". Form sheet appears (venue name, time, optional address). Custom card replaces the slot, shown with ✏️ badge and positive accent.

**US-11: Remove a slot**
> User taps ⋯ → "Remove slot". Card removed. Gap stays empty — not auto-filled.

**US-12: Redeal**
> User taps "Redeal". All unlocked slots are recomposed as a batch. Locked slots stay. Engine optimizes new cards together (proximity, variety, pacing).

### Save & Return

**US-13: Save to calendar**
> User taps "Save to calendar". All slots written as EKEvents with: venue name as title, time range, venue address as location string, coordinates as EKStructuredLocation. All slots auto-lock. Button changes to "✓ Saved to calendar" (dimmed).

**US-14: Return to saved plan**
> User reopens app. Sees their saved plan with all slots locked. Can unlock individual slots via ⋯ and redeal to draw new cards. Can re-save to update calendar.

### Contextual

**US-15: Directions from expanded card**
> User taps "Directions" on expanded card. Apple Maps opens with venue coordinates as destination (not just name).

**US-16: Time-aware composition**
> Composing at 2 PM for today: only afternoon and evening slots generated. No morning suggestions.

**US-17: Weather-aware composition**
> Rainy days suggest indoor venues. Sunny days suggest outdoor. Forecast for the specific planned day is used.

**US-18: Opening hours awareness**
> Venues only suggested at times they're open. If opening hours can't be parsed, treat as always open (fail-open).

**US-19: Plan for a different city**
> User taps city picker in hero → selects Basel. Hero, weather, venue pools, and composition all switch to Basel context.

**US-20: Stay-at-home card**
> Bad weather or user preference: engine may deal a stay-at-home activity. Card has dashed border, house icon, no photo thumbnail. Expands without photo panel.

## 6. Screen States

### State 1: Empty (no calendar events)
- Hero: navy gradient, "Plan your {Day}", weather row, city picker
- Date strip: 14 days scrollable, 5 visible, calendar icon trailing
- Weather summary card
- "Plan my day" CTA button

### State 2: Calendar Preview
- Same hero + date strip
- Weather card with "{N} events in your calendar" subtitle
- "From your calendar" section label
- Calendar event cards: blue accent bar, 📅 icon, locked badge, time + name
- "Fill the gaps" CTA with slot type subtitle

### State 3: Hand Dealt
- Hero changes to "Your {Day}"
- Timeline of cards with travel connectors between them
- Card types:
  - **Activity**: terracotta accent, photo/icon thumbnail, tags (Outdoor/Indoor/Free), distance
  - **Restaurant**: green accent, photo/icon thumbnail, star rating, cuisine, price tier, distance
  - **Calendar**: blue accent, light blue tint background, locked badge
  - **Stay-at-home**: dashed border, house icon, no accent bar
  - **Custom**: green accent, ✏️ badge
- Bottom action bar: "Save to calendar" (primary) + "Redeal" (secondary)

### State 4: Saved Plan (returning user)
- All cards show 🔒 Locked badge
- "Save to calendar" button dimmed ("✓ Saved to calendar")
- "Redeal" still available
- Cards show compact view (no reason text, no footer — just badge + time + name)

### Card Expanded State
- Photo slides to top (full-width, 160pt, activity/restaurant only)
- 2×2 metadata grid: Address, Hours, Distance, Price
- Full reason text
- Tags row
- Action buttons: "📍 Directions" (terracotta) + "🌐 Website" (navy)
- ⋯ menu still accessible

### Context Menu (⋯)
- **On unlocked card:** Lock this slot · Replace with my own · Remove slot
- **On locked card:** Unlock · Replace with my own · Remove slot
- **On calendar card:** Unlock · Remove slot (no replace — it's a calendar event)
- Remove is destructive styling (red text)

## 7. Date Selection

- **Date strip**: horizontal scrolling row of date cells, 14 days ahead from today
- **5 cells visible** at a time, scroll right for more
- **Cell format**: day name (3-letter uppercase) + day number
- **Selected state**: navy background, white text
- **Future/dim state**: muted text for dates beyond this week
- **Calendar icon**: trailing position, opens date picker sheet for dates beyond 14 days
- **Auto-default**: today if before 22:00, tomorrow if after 22:00

## 8. Architecture

### Approach

Rewrite the orchestration layer (ViewModel + views). Keep working services.

### What Gets Rewritten

| Component | Current | New |
|-----------|---------|-----|
| `TodayViewModel` (2,047 lines) | God object | Split into focused state machine + smaller managers |
| `TodayView` (899 lines) | Monolithic view with news/plan toggle | Plan-only view, news extracted to NewsTab |
| `AgendaSlotCard` (1,115 lines) | Complex card with swap tray, execution mode | Simplified card without swap tray or execution mode |
| `TodayHeroBanner` (386 lines) | News/plan toggle hero | Plan-only hero with city picker |
| `CalendarSwipeView` | Tinder-style swipe | Removed — calendar events auto-appear as locked cards |
| `YourDayConfigSection` | Vibe selector, kid count | Removed |
| `ExecHeaderView`, `TravelConnectorView` | Execution mode UI | ExecHeader removed, TravelConnector simplified |

### What Gets Kept (services)

| Service | Reason |
|---------|--------|
| `GapAnalysisEngine` | Works correctly, clean input/output |
| `AgendaComposer` | Claude API integration works |
| `TemplateEngine` | Offline fallback works (recently fixed) |
| `CalendarService` | EKEventStore wrapper works |
| `CalendarSyncChecker` | Event detection logic works |
| `AnchorStore` | Persistence works |
| `FreshnessScorer` | Venue scoring works |
| `AgendaCache` | Disk caching works |
| `CacheManager`, `APIClient` | Infrastructure, untouched |

### New ViewModel Structure

Instead of one 2,047-line ViewModel, split into:

1. **PlanViewModel** (~300-400 lines) — owns the plan state machine:
   - `planState: PlanState` enum (`.empty`, `.calendarPreview([EKEvent])`, `.dealt(DayAgenda)`, `.saved(DayAgenda)`)
   - `selectedDate: Date`
   - `planningCity: PlanningCity`
   - `deal()`, `redeal()`, `lock(slotId:)`, `unlock(slotId:)`, `remove(slotId:)`, `replaceWithCustom(slotId:, ...)`, `saveToCalendar()`
   - Delegates to existing services for composition

2. **DateStripViewModel** (~50 lines) — date selection state, generates 14-day range

3. **CalendarBridge** (~100 lines) — wraps CalendarService + CalendarSyncChecker for the specific flows this tab needs (fetch events for date, export plan, detect new events)

### State Machine

```
                    ┌─────────────┐
        app open    │             │  select date
       ──────────►  │    empty    │ ◄──────────
                    │             │  (no plan for this date)
                    └──────┬──────┘
                           │
            calendar events found?
                    ┌──────┴──────┐
                    │             │
                no  ▼             ▼  yes
          ┌─────────────┐  ┌──────────────┐
          │   empty     │  │  calendar    │
          │  (show CTA) │  │  preview     │
          └──────┬──────┘  └──────┬───────┘
                 │                │
          "Plan my day"    "Fill the gaps"
                 │                │
                 └────────┬───────┘
                          ▼
                    ┌─────────────┐
                    │             │
                    │    dealt    │ ◄─── redeal
                    │             │
                    └──────┬──────┘
                           │
                     "Save to calendar"
                           │
                           ▼
                    ┌─────────────┐
                    │             │
                    │    saved    │ ◄─── unlock + redeal
                    │             │
                    └─────────────┘
```

Selecting a different date always transitions to `.empty` first, then checks calendar → `.calendarPreview` or stays `.empty`.

### Data Flow

```
User taps "Plan my day" / "Fill the gaps"
  │
  ├─ PlanViewModel.deal()
  │   ├─ Fetch weather for date (APIClient)
  │   ├─ Fetch activity pool (APIClient, cached)
  │   ├─ Fetch restaurant pool (APIClient, cached)
  │   ├─ Get anchors for date (AnchorStore — calendar events converted to anchors)
  │   ├─ GapAnalysisEngine.analyse(anchors)
  │   ├─ FreshnessScorer.buildScoredPool()
  │   ├─ AgendaComposer.compose() || TemplateEngine.buildAgenda()
  │   ├─ Compute travel estimates between slots
  │   ├─ Cache result (AgendaCache)
  │   └─ Set planState = .dealt(agenda)
  │
  └─ View reacts to planState change → renders timeline
```

## 9. Card Design (Znuni Design System)

### Collapsed Card
- **Layout**: `HStack(spacing: 12)` — photo (76×76) + body
- **Background**: `znSurface` (calendar cards: `znNavy.opacity(0.04)`)
- **Corner radius**: 16pt
- **Shadow**: `AppShadow.card` (black 8%, radius 8, y:2)
- **Accent bar**: 3pt left, colors: terracotta (activity), positive/green (restaurant), navy-light/blue (calendar)
- **Photo**: 76×76, 10pt radius, gradient+icon fallback, category badge bottom-left
- **Stay-at-home**: dashed border (1.5pt), house icon, no accent bar, no shadow
- **Badge row**: 🔒 Locked (navy 8% bg) or ✏️ Custom (positive 8% bg) + ⋯ edit button
- **Eyebrow**: monospaced time + separator + uppercase type label (colored by deck)
- **Name**: Playfair 15pt semibold
- **Reason**: system 12pt light, 2-line clamp, `znBody` color
- **Tags**: capsule pills, `znNeutralTagBg`/`znNeutralTagText`, colored variants for Indoor/Outdoor/Free
- **Footer**: divider + distance badge + "Tap to expand ›"

### Expanded Card
- **Photo**: full-width, 160pt height (activity/restaurant only, not stay-at-home/calendar)
- **Accent bar**: fades to 0 opacity
- **Shadow**: `AppShadow.cardExpanded` (znNavy 12%, radius 12, y:6)
- **Metadata grid**: 2×2, label (10pt uppercase muted) + value (12pt medium ink) — Address, Hours, Distance, Price
- **Reason**: full text, no line clamp
- **Actions**: "📍 Directions" (terracotta 8% bg) + "🌐 Website" (navy 6% bg), 40pt height, 10pt radius

### Travel Connector
- **Dashed line**: 2pt width, 32pt height, 3px dash pattern, `znBorder` color
- **Chip**: capsule, 11pt text, `znMuted` color, transport icon (🚶/🚋), `znBorder` 50% bg
- **Left padding**: 14pt (aligns with timeline dot if used)

## 10. Travel Time Accuracy

Current bug: straight-line distance assumed as walking. Fix:

1. **< 1 km straight-line**: show as walking, estimate = distance / 80m per minute
2. **1–3 km**: show as tram/transit, estimate = distance / 250m per minute + 5 min wait
3. **> 3 km**: show as tram/transit, estimate = distance / 400m per minute + 5 min wait
4. **Future enhancement**: use MapKit `MKDirections` for actual travel time (async, cache results)

## 11. Opening Hours

Create `OpeningHoursParser` utility:

- Parse free-text strings (e.g. `"Tue-Sun 10:00-17:00"`, `"Daily 9:00-18:00"`) into structured day-of-week → open/close times
- `isOpen(activity:, at: Date) -> Bool`
- **Fail-open**: if parsing fails, treat as always open
- Used by both TemplateEngine and FreshnessScorer to filter venue pools before composition

## 12. Features Cut / Deferred

| Feature | Status |
|---------|--------|
| Execution mode (real-time progress, check-ins) | Deferred |
| Family session config / kid count | Cut |
| User-facing vibe/archetype selector | Cut |
| Swap tray (3 alternatives per slot) | Replaced by redeal |
| Tinder-style calendar swipe | Replaced by auto-appearing locked cards |
| "Suggest another nearby" cycling | Replaced by redeal |
| Plan/News toggle within same tab | Replaced by separate tabs |
| Reflow banner (after time edit) | Replaced by redeal |
| Slot time editing | Replaced by remove + custom replace |
| Stale plan indicators (FreshnessScorer UI) | Deferred |
| Multi-day plan store | Simplified — one plan per date in cache, no special store |

## 13. Migration Notes

- **News tab**: Extract current news view from TodayView into standalone NewsView + NewsViewModel. Existing NewsHeroBanner, NewsCard, BriefingCard etc. move to News tab.
- **Tab bar**: Update `ContentView.swift` from 3 tabs (Today/Discover/Settings) to 4 tabs (News/Today/Discover/Settings). Update `AppTab` enum.
- **Deep links**: `swissportal://` scheme routes unchanged — just map to new tab structure.
- **Old files to delete**: `CalendarSwipeView`, `YourDayConfigSection`, `ExecHeaderView`, `SlotSwapSheet`, `SlotEditSheet`, `CustomSlotFormSheet` (replaced by simpler sheet), `MultiDayPlanStore`, `TimelineShifter`.
- **Old TodayViewModel**: Delete entirely, replaced by PlanViewModel + DateStripViewModel + CalendarBridge.
