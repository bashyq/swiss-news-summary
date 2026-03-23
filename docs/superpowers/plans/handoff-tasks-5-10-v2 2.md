# Znuni Rearchitecture — Handoff for Xcode Claude

> **Updated 2026-03-21 (end of session).** Tasks 1–4 complete + 15 UX fixes applied.
> Branch: `claude/plan-ios-app-4aOQo` (fully pushed to remote)

---

## What's Been Done (Claude Code)

### Structural Rearchitecture (Tasks 1–4)
- 5 tabs → 3 tabs: Today, Discover, Settings
- `DiscoverView` with sunshine/snow/events hero cards + 2×2 browse grid
- `DiscoverRoute` enum with 9 navigation routes wired to existing views
- `WeekendView`, `WeekendDayCard`, `WeekendViewModel` deleted
- `ExploreView`, `ExploreHeroBanner` deleted
- Event CTA renamed to "Plan around this →"

### Analytics & Sharing
- TelemetryDeck SDK integrated (app ID: `E10CE9CC-BD37-4484-9845-054D7CD55CEA`)
- `ZnuniEvent` enum with 15 analytics events wired into ~12 files
- `PlanShareFormatter` + `ShareSheet` + `SharePlanButton`

### Bug Fixes
- **TemplateEngine opening hours**: removed incorrect midnight check that emptied activity pool
- **Time-aware planning**: template fallback now filters past slots for today (no 9 AM at 11 AM)
- **SlotEditSheet blank**: switched from `.sheet(isPresented:)` to `.sheet(item:)`
- **Rebuild → pull-to-refresh**: removed Rebuild button, Plan mode pull-to-refresh triggers rebuild
- **Travel connector**: uses home address when set, shows transport mode (walk/tram)
- **"What's on today" removed**: events section removed from Today tab (now in Discover)
- **Briefing duplicate**: top story filtered from news feed
- **Sync button**: hidden when no pending calendar events
- **Locked slots preserved on rebuild**: `rebuildAgenda()` now keeps locked slots
- **Save to Calendar locks all slots**: export + lock in one action
- **Rating filter**: restaurants < 4.0 excluded from planner
- **Template fallback caches to disk**: no double-compose
- **Rebuild preserves exported calendar events**: no longer deletes EKEvents on refresh
- **Calendar export includes venue location**: EKStructuredLocation with coordinates

### UX Polish
- Hero banners unified (Sunshine/Snow: navy + themed glow, Settings: compact navy hero, Discover: added weather row, Activities: linear gradient drill-down style)
- Category pills trailing fade on scroll
- Date picker "Pick date →" dashed outline pill
- Stay-at-home cards: dashed border + house icon
- "Your day" header flattened to muted eyebrow
- Events hero card font aligned with Sunshine/Snow
- Tab bar gear: Canvas-drawn icon matching others
- Restaurant cards: consistent 76x76 photos, neutral tag colors
- Open/Closed badges: standardized green/red across views
- "Lunch" renamed to "Find *restaurants*" with Playfair italic
- Time-of-day greetings (morning/afternoon/evening)
- ActivityCard restyled to compact row layout matching CategoryDetailView

---

## BUGS — Fix These First

These are confirmed bugs from user testing. Fix in this priority order.

### Bug 1: Calendar Sync button never appears
**Symptom:** User has events in iOS Calendar (e.g. for tomorrow). Switches to tomorrow's date pill. The "Sync" button never appears. No indication that calendar events exist.

**Root cause (suspected):** `checkCalendarSync()` only runs on `agendaSection.onAppear` — it does NOT re-run when the user switches day pills. So switching from today → tomorrow never triggers the calendar check for that day.

**Fix:** Re-run `checkCalendarSync()` whenever `selectedPlanDay` changes. Add `.onChange(of: viewModel.selectedPlanDay)` that triggers the check. Also verify `CalendarService.shared.hasAccess` returns true (debug logging already added to `CalendarSyncChecker`).

**Files:** `Views/Today/TodayView.swift` (where the sync button lives), `ViewModels/TodayViewModel.swift` (where `checkCalendarSync()` is defined)

**Test:** Add a real event to iOS Calendar for tomorrow → switch to tomorrow pill → Sync button appears → tap Sync → Tinder-style swipe screen → accept → event becomes anchor.

### Bug 2: Pick Date doesn't create pill or compose plan
**Symptom:** Tap "Pick date →" → select March 28 → tap Done → nothing happens. User stays on current view. Expected: a new pill "28 Mar" appears in the day row and a draft plan is composed for that date.

**Root cause:** The `DatePickerSheet` sets `selectedPlanDay = .specific(pickedDate)` but the day pill row doesn't render `.specific` dates, and `composeAgendaForDate()` may not be triggered for the new date.

**Fix:**
1. Day pill row needs to include the `.specific(date)` pill when one is selected
2. `.onChange(of: selectedPlanDay)` should trigger `composeAgendaForDate()` for the new date
3. The pill should show a short label like "Mar 28"

**Files:** `Views/Today/DatePickerRow.swift`, `ViewModels/TodayViewModel.swift`

**Test:** Pick March 28 → pill appears in row → plan composes with 4 slots → label shows "Mar 28".

### Bug 3: "Replace with my own" shows blank sheet
**Symptom:** In Plan mode, tap (...) on a slot → submenu appears → tap "Replace with my own" → white empty card slides up.

**Root cause:** Similar to the SlotEditSheet blank bug we fixed — likely another `.sheet(isPresented:)` timing issue, or the custom replacement view has no content for certain slot types (especially stay-at-home activities).

**Fix:** Check what sheet is presented when "Replace with my own" is tapped. Ensure it uses `.sheet(item:)` pattern and passes the slot data correctly. Verify it works for all slot types including stay-at-home.

**Files:** `Views/Today/AgendaSlotCard.swift` (context menu), whatever sheet is presented for custom replacement

**Test:** Tap (...) on any slot → "Replace with my own" → form appears with venue name field, optional address, time picker.

### Bug 4: Travel times between cards are wrong
**Symptom:** Shows "5 min walk" between venues that are 45 min tram ride apart. The from-home connector also has wrong estimates.

**Root cause:** Travel time calculation may be using straight-line distance and assuming walking, or coordinates aren't being passed correctly between slots.

**Fix:** Check `TravelConnectorView` — how does it compute travel time? If it's using Haversine distance, it needs to use MapKit `MKDirections` for actual travel time. At minimum, if straight-line distance > 1km, show tram/transit time estimate instead of walking.

**Files:** `Views/Today/TravelConnectorView.swift`, check if there's a travel time calculation helper

**Test:** Two venues 5km apart → connector shows "~20 min tram" not "5 min walk".

### Bug 5: Directions to Apple Maps seem off
**Symptom:** When getting directions from a slot card, the destination seems wrong.

**Root cause:** Check if coordinates (lat/lon) or just venue name is being passed to the Apple Maps URL. If only name, geocoding may resolve to wrong location.

**Fix:** Pass coordinates explicitly in the Maps URL: `maps.apple.com/?daddr={lat},{lon}`. Venues in the activity/restaurant data all have lat/lon.

**Files:** Check `AgendaSlotCard.swift` or wherever the "Get directions" button builds the Maps URL

**Test:** Tap directions on a slot → Apple Maps opens with correct pin at the venue's actual location.

### Bug 6: Calendar export missing full address
**Symptom:** When saving plan to calendar, the EKEvent has coordinates (EKStructuredLocation) but no human-readable address string.

**Fix:** Set `event.location` to the venue's address string (or "venue name, city" as fallback). `EKStructuredLocation` already has coordinates from our fix — just add the `location` string property too.

**Files:** `Services/CalendarService.swift` (wherever EKEvent is created for export)

**Test:** Save plan → open Calendar app → tap event → location shows venue name + address, tap for directions.

### Bug 7: Venues suggested at times they're not open
**Symptom:** Tram Museum suggested at 10am Sunday but it doesn't open until 1pm. Venues are being slotted at times they're closed.

**Root cause:** The TemplateEngine was recently fixed (it was filtering ALL venues out due to a broken opening hours check). The fix removed the check entirely, making it too permissive — it no longer validates whether a venue is open at the proposed slot time.

Opening hours exist as free-text strings on the `Activity` model (e.g. `"Tue-Sun 10:00-17:00"`, `"Daily 9:00-18:00"`, `"Mon-Fri 8:00-17:00, Sat 10:00-16:00"`). These come from the worker's `activities.js`.

**Fix:**
1. Create an `OpeningHoursParser` utility that parses these strings into structured data (day-of-week → open/close times)
2. In `TemplateEngine.swift`: when selecting a venue for a slot, check if the venue is open at the slot's start time on the slot's day-of-week. Filter out closed venues. **Be very careful** — the previous bug was caused by an overly aggressive filter that emptied the pool. If parsing fails (unrecognized format), treat the venue as "always open" (fail-open, not fail-closed).
3. In `AgendaComposer.swift`: include opening hours in the venue data sent to Claude in the system prompt, so Claude can respect them when selecting venues.

**Files:**
- Create: `Services/OpeningHoursParser.swift`
- Modify: `Services/TemplateEngine.swift` — add `isOpen(activity:, at: Date)` check in venue selection
- Modify: `Services/AgendaComposer.swift` — include opening hours in venue pool sent to Claude

**Test:** Plan for Sunday → morning slot does NOT suggest Tram Museum (opens 1pm) → afternoon slot CAN suggest it. Venues with unparseable hours still appear (fail-open).

---

## Remaining Tasks (from original plan)

### Task 7: Smart Nudge Engine (refinement)

**Status:** `NudgeEngine.swift` and `SmartNudgeCard.swift` exist and are wired into DiscoverView. Nudge re-evaluates on weather/data changes (`.onChange` modifiers added).

**What may need work:** Verify the nudge actually appears with real data. Priority: sunshine escape > upcoming event (3 weeks) > snow alert (Nov-Apr).

**Test:** Overcast weather + sunny destination → sunshine escape nudge at top of Discover.

### Task 8: Anchor Location + Proximity Scoring

**Goal:** Anchors can have addresses. Slots adjacent to anchors prefer nearby venues.

**Files to modify:**
- `Models/DayAnchor.swift` — Add `address: String?`, `lat: Double?`, `lon: Double?`
- `Views/Today/AnchorFormSheet.swift` — Add optional address field + `CLGeocoder`
- `Services/FreshnessScorer.swift` — Verify `applyProximityBias()` is called
- `Services/AgendaComposer.swift` — Add proximity rule to Claude prompt

**Test:** Add anchor with address → adjacent slots prefer venues within ~20 min travel.

### Task 9: "Plan Around This" Universal CTA

**Goal:** Activity/restaurant/event cards all get "Plan around this →".

**Files:**
- `Views/Activities/ActivityCard.swift` — Add CTA in expanded state
- `Views/Lunch/LunchCard.swift` — Same CTA
- `Views/Events/EventCard.swift` — Already partially wired (navigates to Today tab)
- `Views/Events/DayDetailView.swift` — Already partially wired

**Depends on:** Task 8 (AnchorFormSheet pre-fill).

**Test:** Expand activity → "Plan around this →" → anchor form pre-filled → save → Today tab composes around it.

### Task 10: Final Verification

Full simulator walkthrough:
- 3 tabs render correctly
- Discover: hero cards → sunshine/snow/events drill-downs
- Browse grid → activities/museums/parks/restaurants
- Date picker → compose for any date within 14 days
- City context → "Plan a day in {city}"
- "Plan around this" → anchor form → Today tab
- Pull-to-refresh rebuilds in Plan mode (preserves locked slots)
- Calendar sync: read flow (import events) + write flow (export plan)
- Share plan works
- Analytics signals visible in TelemetryDeck dashboard
- Travel connectors show realistic times
- All hero banners consistent navy style

---

## UX Polish (Low Priority)

| Item | Detail |
|------|--------|
| Events empty state | When a calendar day has zero events, show "Browse activities →" + "Plan this day →" CTAs instead of blank |
| Browse grid Canvas art | Verify illustrations migrated correctly from old `BrowseByTypeSection.swift` |
| TelemetryDeck dashboard | Toggle "Show test data" to see simulator signals |

---

## Architecture Reference

### Key files
| File | What |
|------|------|
| `App/ContentView.swift` | 3-tab bar, `DiscoverNavigationStack`, `DiscoverRoute` enum |
| `App/AppState.swift` | `AppTab` (3 cases), deep links, `pendingPlanDate`, `pendingPlanRequest` |
| `Views/Discover/DiscoverView.swift` | Hero + weather + hero cards + browse grid + nudge |
| `ViewModels/TodayViewModel.swift` | Central planner logic, `planningCity`, `selectedPlanDay`, `checkCalendarSync()` |
| `Models/DayAgenda.swift` | `PlanDay` enum, `AgendaSlot`, `DayAgenda` |
| `Models/PlanningCity.swift` | City context model with `coveredCities` |
| `Services/AgendaComposer.swift` | Claude API prompt + parsing |
| `Services/TemplateEngine.swift` | Offline fallback — 7 archetypes, fixed opening hours bug |
| `Services/FreshnessScorer.swift` | Venue scoring + `applyProximityBias()` |
| `Services/AgendaCache.swift` | Disk cache — has `city` parameter |
| `Services/NudgeEngine.swift` | Smart nudge evaluation |
| `Services/CalendarService.swift` | EKEventStore wrapper — read + write |
| `Services/CalendarSyncChecker.swift` | Filters calendar events vs anchors vs discarded |
| `Services/CalendarExportStore.swift` | Tracks exported EKEvent IDs per slot |
| `Services/Analytics.swift` | TelemetryDeck wrapper (app ID in file) |
| `Services/ZnuniEvent.swift` | 15 analytics events |

### What NOT to touch
- `GapAnalysisEngine.swift` — works as-is
- `TemplateEngine.swift` — just fixed, works correctly now
- `AnchorStore.swift` — works as-is
- Worker (`worker/src/`) — no changes needed, freshly deployed

### Spec documents
- Rearchitecture spec: `design system/znuni-rearchitecture-spec-v2.md`
- Full implementation plan: `docs/superpowers/plans/2026-03-16-rearchitecture-3-tabs.md`
- User flows mockup: `design system/znuni-user-flows.html`
- Analytics spec: `docs/superpowers/plans/znuni-analytics-and-share-spec.md`
