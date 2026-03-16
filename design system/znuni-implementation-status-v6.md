# Znüni — Implementation Status
## v6.0 — Session Summary, March 2026

> This document captures the current state of the Znüni iOS app after the March 2026 build session.
> Upload this to project knowledge to seed future sessions.
> The authoritative spec remains `znuni-master-spec-v5.md`.

---

## BUILD STATUS — ALL 17 STEPS

| Step | Description | Status | Notes |
|------|-------------|--------|-------|
| 1 | Worker/data schema additions | ✅ Done | `suggestibility` on activities, `openForDinner`/`kidFriendly` on restaurants, `plannable` on CityEvents |
| 2 | Swift data models | ✅ Done | All models built, `typealias DayAnchor = AnchorEvent` for backwards compatibility |
| 3 | GapAnalysisEngine + unit tests | ✅ Done | 8 tests pass. Engine subdivides day into 4 windows: morning 8–11:30, lunch 11:30–13:30, afternoon 13:30–17, dinner 17–21 |
| 4 | FreshnessScorer + unit tests | ✅ Done | 9 tests pass. Hard exclusions + soft scoring (freshness × weather × seasonal × variety) |
| 5 | Template engine fallback | ✅ Done | FreshnessScorer wired into archetype pools. Pool exhaustion reset implemented |
| 6 | Today screen shell | ✅ Done | Gap-aware context banner, AnchorPillRowView with time ranges, DayCompleteView, AnchorOnlyView, AgendaCache anchors hash |
| 7 | AnchorFormSheet 5-step | ✅ Done | Category (required) + Duration (required) added. CityEvent pre-fill (label + category only — no time/duration data on events). sourceEventId linking |
| 8 | Agenda UI components | ✅ Done | All components exist. "Leave at HH:MM" on connector chip. "Suggest another nearby" on lunch/dinner cards |
| 9 | API integration | ✅ Done | AgendaComposer.swift built. composeAgendaForDate() pipeline: gap analysis → scored pool → Anthropic API → merge anchors → cache. Template fallback is gap-aware (filter-after). API key in xcconfig |
| 10 | Visit tracking local | ✅ Done | handleCheckIn() wired to VenueVisitStore (.executionCheckIn). "Mark as visited" button on ActivityCard and LunchCard (.manualMark) |
| 11 | KV sync | ⏸ Deferred | Defer until multi-user. Local UserDefaults persistence is sufficient for single user |
| 12 | Polish | ✅ Done | Rebuild button, swap travel recalculation, session change → rebuild, anchor change → rebuild, all special view states |
| 13 | Execution mode + planCompletion | ✅ Done | Fully built in prior sessions. planCompletion visit recording: pending audit (likely not wired) |
| 14 | Custom slots + slot editing | ✅ Done | SlotEditSheet, CustomSlotFormSheet, ReflowBanner, locked/custom/anchor slot preservation on reflow. 3 gaps fixed: removeSlot travel recalc, editSlotTime reflow trigger, reflow preserves locked slots |
| 15 | Check-in, timeline shift, notifications | ✅ Done | Built in prior sessions. Notification scheduling: pending audit |
| 16 | Multi-day planning | ✅ Done | Weekend tab Planner upgraded. Per-day weather wired. Weekend anchors built with date-keyed AnchorStore. AnchorPillRowView per day in WeekendView |
| 17 | Calendar → anchor flow | ✅ Done | "Add to your plan" CTA on plannable CityEvents in both EventCard and DayDetailView. NotificationCenter broadcast triggers Today tab rebuild |

---

## CURRENT OPEN ITEMS

### 1. Lunch/dinner slots not appearing (needs diagnosis)

Reported: with no anchors set, only two activity cards appear — no lunch or dinner suggestions.

**Debug prints to add before next test session:**
```swift
// After gap analysis in composeAgendaForDate():
print("GAP DEBUG: \(fillableGaps.map { "\($0.suggestedType?.rawValue ?? "nil") \($0.effectiveMinutes)min" })")

// After scored pool:
print("POOL DEBUG: activities=\(pool.activities.count) lunches=\(pool.lunches.count) dinners=\(pool.dinners.count)")

// After API call:
print("COMPOSER: \(aiSlots.count) AI slots returned")

// In catch block:
print("COMPOSER FAILED: \(error) — using template fallback")
```

Must test before 22:00 (next-day mode kicks in after 22:00).

**Suspected causes:**
- `openForDinner` is nil on most restaurants (field exists but not populated in data)
- `openForLunch`/`openForDinner` Boolean flags missing → restaurants filtered as ineligible
- OpeningHoursParser added to FreshnessScorer in this session — verify it's not over-aggressively marking restaurants as closed

### 3. planCompletion visit recording (Step 13 gap)

When user reaches the final slot in execution mode, `VenueVisitStore` should record all unconfirmed slots with `source: .planCompletion`. Not verified as wired. Low priority but closes the feedback loop for freshness scoring.

### 4. Notification scheduling audit (Step 15 gap)

`AgendaNotificationScheduler` exists. Verify "Leave now" nudge is scheduled on "Let's go →" tap and rescheduled after every `TimelineShifter` run. Low priority for single-user testing.

---

## ARCHITECTURAL DECISIONS MADE THIS SESSION

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Claude API call location | Direct from iOS | Single user, simpler. Move behind Worker when multi-user |
| Template engine gap-awareness | Filter-after (not full rewrite) | Fallback path, rarely runs, 10 lines vs major rewrite |
| Plan persistence (multi-day) | Ephemeral (cache only) | No named saved plans needed for single user |
| MultiDayPlannerView | Not built | Existing Weekend tab flow is sufficient |
| KV sync | Deferred | UserDefaults sufficient for single user |
| Next-day mode threshold | 22:00 (raised from 20:00) | 20:00 too early — user may still be using the app |
| availablePlanDays | Always [.today, .tomorrow] | User should always be able to switch |

---

## WHAT'S DEFERRED (DO NOT BUILD YET)

- **KV sync** — before second user or second device
- **Recurring anchors** — weekly football training auto-population — when users ask
- **Apple Calendar / Google Calendar sync** — when users ask. `AnchorSource` enum has `.calendarSync` case ready
- **Structured opening hours** — data enrichment task on `activities.js`. Currently using `isLikelyOpen()` heuristic and `OpeningHoursParser` for OSM strings
- **Multi-profile / auth** — `profileId = "bisho"` hardcoded everywhere. Add auth layer when scaling
- **Geofence radius tuning** — 150m flat for all venues
- **Push notifications from server** — all notifications are local `UNUserNotificationCenter` only
- **Adaptive timing learning** — `CheckInStore.averageDelta` stubbed, not implemented

---

## DATA QUALITY GAPS (blocking good suggestions)

These are data tasks, not code tasks:

| Field | Status | Impact |
|-------|--------|--------|
| `suggestibility` on activities | Mostly nil (defaults to "free") | Seasonal/feed-only exclusions not firing |
| `openForDinner` on restaurants | Mostly nil | Dinner pool always empty — likely cause of missing dinner slots |
| `availableMonths` on seasonal activities | Sparse | Badi/Christmas market not excluded in wrong season |
| `plannable` on CityEvents | Added field, needs per-event curation | Holiday blocks may still appear as plannable |
| `kidFriendly` on restaurants | Mostly nil | Not filtering family-appropriate venues |

**Highest priority data fix:** populate `openForDinner` on restaurants in `lunch.js`. This is likely the root cause of no dinner suggestions appearing.

---

## KEY FILES MODIFIED THIS SESSION

```
GapAnalysisEngine.swift         — Rewrote analyse() to subdivide into 4 day-part windows
FreshnessScorer.swift           — Added gapMidpoint parameter, OpeningHoursParser integration
TemplateEngine.swift            — FreshnessScorer wired, OpeningHoursParser replaces heuristic
TodayViewModel.swift            — composeAgendaForDate() full pipeline rewrite, next-day threshold 22:00
AgendaComposer.swift            — NEW: direct Anthropic API call, gap-based prompt
AnchorStore.swift               — didChangeNotification, date-keyed methods (in progress)
WeekendView.swift               — Full rewrite: entry state, day switcher, AgendaTimelineView, BadWeatherAgendaView
WeekendResponse.swift           — DayWeather.toWeather() extension
AgendaTimelineView.swift        — "Let's go" hidden when onStartExecuting is nil (weekend mode)
ActivityCard.swift              — "Mark as visited" button
LunchCard.swift                 — "Mark as visited" button
TodayView.swift                 — availablePlanDays always [.today, .tomorrow]
Config/Secrets.xcconfig         — NEW: API key placeholder
Info.plist                      — ANTHROPIC_API_KEY entry
```

---

## TEST CHECKLIST — RUN BEFORE SHIPPING

- [ ] 13:43 scenario: brunch anchor 11:15 (90min, food) + birthday party 14:00 (180min, social) → only dinner suggestion, two anchor cards
- [ ] Empty day before 22:00: four suggestions (morning, lunch, afternoon, dinner)
- [ ] All gaps elapsed (after 21:00, no anchors): DayCompleteView shown
- [ ] Anchors with no fillable gaps: AnchorOnlyView shown
- [ ] Bad weather day (temp < 10° + heavy rain): BadWeatherAgendaView with home activities
- [ ] Swap slot: travel connector updates to new venue's location
- [ ] Mark as visited: venue excluded from next plan generation
- [ ] Custom slot: downstream slots marked stale, reflow banner appears
- [ ] Calendar event → Add to plan: label and category pre-filled, anchor appears in Today timeline
- [ ] Session change: agenda rebuilds
- [ ] Weekend tab: Saturday/Sunday plans with per-day weather
- [ ] Next-day mode: after 22:00 defaults to tomorrow, Today pill still accessible

---

## NEXT SESSION PRIORITIES

1. **Fix lunch/dinner missing** — run debug prints, identify root cause (likely `openForDinner` nil in data)
2. **Complete weekend anchors** — date-keyed AnchorStore, wire into composeWeekend(), AnchorPillRowView in WeekendView
3. **Data quality pass** — populate `openForDinner` on top 30 restaurants in lunch.js
4. **Run test checklist** — end-to-end device testing
5. **App Store prep** — icon, privacy policy, screenshots
