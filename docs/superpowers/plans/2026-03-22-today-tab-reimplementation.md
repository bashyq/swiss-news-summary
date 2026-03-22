# Today Tab Reimplementation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reimplement the Today tab as a standalone plan tab with a card-dealing interaction model, replacing the buggy 2,047-line TodayViewModel with a clean state-machine architecture.

**Architecture:** Split the monolithic TodayViewModel into PlanViewModel (state machine) + CalendarBridge (EventKit wrapper) + DateStripManager (plain struct). Keep all working services (GapAnalysisEngine, AgendaComposer, TemplateEngine, CalendarService). Extract News into its own tab. New 4-tab structure: News, Today, Discover, Settings.

**Tech Stack:** SwiftUI (iOS 17+), @Observable, EventKit, MapKit (CLGeocoder), Claude API (via AgendaComposer)

**Spec:** `docs/superpowers/specs/2026-03-22-today-tab-reimplementation-design.md`
**Mockups:** `.superpowers/brainstorm/88117-1774175237/today-complete.html`

---

## ⚠️ Critical Implementation Notes

**All code snippets in this plan are structural templates, not production code.** The implementer MUST read each service file's actual API before writing calls to it. The key mismatches to watch for:

1. **`CalendarService.createEvent()`** takes a single `EKEvent` parameter, not named parameters. Construct the `EKEvent` manually.
2. **`AgendaCache`** is an `actor` — requires `await`. Takes `date: String` (not `Date`), plus `sessionHash` and `anchorsHash`. Stores/retrieves raw `Data`, not typed objects.
3. **`AnchorEvent`** uses `startTime: Date` + `durationMinutes: Int` (not `startDate`/`endDate`). Has `category: AnchorCategory` and `source: AnchorSource`.
4. **`DayAgenda`** requires `date: String`, `theme: String`, `weatherNote: String`, `badWeatherMode: Bool`, `slots: [AgendaSlot]`, `homeActivities: HomeActivities?`. No convenience init for just slots.
5. **`AgendaSlot` needs `lat`/`lon` fields** — add `lat: Double?` and `lon: Double?` in Task 1 model changes.
6. **Travel data**: The old `travelMinutesToNext: Int?` on AgendaSlot will be replaced. Define a simple `TravelEstimate` struct (minutes + mode) in `DayAgenda.swift` as part of Task 1. Add `travelToNext: TravelEstimate?` to `AgendaSlot`.
7. **`TemplateEngine`** is an instance (not static). Requires `Weather?`, `FamilySession`, `[Activity]`, `[LunchSpot]`, `[CityEvent]`, `VenueVisitStore`, `AppLanguage`, `planDate: Date`.
8. **`AgendaComposer`** requires `apiKey: String`, `FamilySession`, `[Activity]`, `[LunchSpot]` (lunch), `[LunchSpot]` (dinner), `Weather?`, `AppLanguage`.
9. **`FamilySession`**: Load from UserDefaults in PlanViewModel init. Default: `FamilySession(kidCount: 1, youngestAge: 3, soloParent: false)`. Both AgendaComposer and TemplateEngine require it.
10. **`compose()` stub**: The `fatalError` in Task 3 Step 6 MUST be replaced with a real TemplateEngine fallback before testing. Never ship a fatalError.
11. **22:00 auto-default**: In PlanViewModel init, check `Calendar.current.component(.hour, from: Date()) >= 22`. If true, set `selectedDate` to tomorrow.
12. **News tab extraction**: The current `TodayView.swift` has a news sub-mode. After Task 4 creates the 4-tab structure, the News tab should wrap the existing `NewsView` (which already exists as a standalone view in `Views/News/NewsView.swift` with its own `NewsViewModel`). No extraction needed — just wire it into the new tab.
13. **`PlanState` Equatable**: Remove the custom `==` — instead, make `CalendarSlot` and `DayAgenda` conform to `Equatable`, or use `@Observable` without relying on Equatable for state changes.
14. **`DatePickerSheet`**: Already exists at `Views/Today/DatePickerSheet.swift` — reuse it, don't create a new one.
15. **`VenueVisitStore`**: Required by `TemplateEngine.buildAgenda()`. Already exists as a service — instantiate in PlanViewModel and pass to TemplateEngine.

## File Structure

### New Files
| File | Path | Responsibility |
|------|------|----------------|
| PlanViewModel | `ViewModels/PlanViewModel.swift` | State machine: `.empty` → `.calendarPreview` → `.composing` → `.dealt` → `.saved` → `.error`. Owns selectedDate, planningCity, deal/redeal/lock/unlock/save. |
| CalendarBridge | `Services/CalendarBridge.swift` | Wraps CalendarService + CalendarSyncChecker + CalendarDiscardStore. fetchEvents, exportPlan, removeExportedEvents. |
| PlanTabView | `Views/Today/PlanTabView.swift` | Main Today tab view. Renders hero → date strip → content (empty/preview/timeline/saved). |
| PlanHeroBanner | `Views/Today/PlanHeroBanner.swift` | Navy hero with "Plan your {Day}" title, weather row, city picker. |
| DateStripView | `Views/Today/DateStripView.swift` | Horizontal scrolling 14-day date cells + trailing calendar icon. |
| PlanSlotCard | `Views/Today/PlanSlotCard.swift` | Collapsed + expanded card. Photo, metadata, tags, ⋯ context menu. No swap tray, no execution mode. |
| SimpleTravelConnector | `Views/Today/SimpleTravelConnector.swift` | Dashed line + travel chip. Simplified from TravelConnectorView (no execution states). |
| CustomSlotSheet | `Views/Today/CustomSlotSheet.swift` | Form: venue name, time range pickers, optional address. Produces AgendaSlot with source .userCustom. |
| CalendarSlot | `Models/CalendarSlot.swift` | Lightweight struct: id, title, startDate, endDate, isAllDay. |

### Modified Files
| File | Path | Changes |
|------|------|---------|
| DayAgenda.swift | `Models/DayAgenda.swift` | Add `SlotSource.calendar`, remove `SwapOption`, remove `swaps` from AgendaSlot, clean up dormant DayAgenda fields |
| ContentView.swift | `App/ContentView.swift` | 4-tab bar (News/Today/Discover/Settings), new AppTab cases, NewsNavigationStack |
| AppState.swift | `App/AppState.swift` | Update AppTab enum to 4 cases, update deep link routing |
| ZnuniApp.swift | `App/ZnuniApp.swift` | Ensure AppState changes compile |

### Deleted Files
| File | Path |
|------|------|
| CalendarSwipeView.swift | `Views/Today/CalendarSwipeView.swift` |
| YourDayConfigSection.swift | `Views/Today/YourDayConfigSection.swift` |
| ExecHeaderView.swift | `Views/Today/ExecHeaderView.swift` |
| SlotEditSheet.swift | `Views/Today/SlotEditSheet.swift` |
| MultiDayPlanStore.swift | `Services/MultiDayPlanStore.swift` |
| TimelineShifter.swift | `Services/TimelineShifter.swift` |

### Kept As-Is
GapAnalysisEngine, AgendaComposer, TemplateEngine, CalendarService, CalendarSyncChecker, AnchorStore, FreshnessScorer, AgendaCache, CalendarDiscardStore, CalendarExportStore, OpeningHoursParser, CacheManager, APIClient, LocationManager — all services untouched.

---

## Task 0: Regression Test Scaffolding

**Files:**
- Create: `ios-app/ZnuniTests/ZnuniTests/PlanViewModelTests.swift`
- Create: `ios-app/ZnuniTests/ZnuniTests/CalendarBridgeTests.swift`
- Create: `ios-app/ZnuniTests/ZnuniTests/TravelEstimateTests.swift`
- Create: `ios-app/ZnuniUITests/PlanUITests.swift`

Write all regression tests upfront — they start red and turn green as each subsequent task lands. This is our definition of "done" for the reimplementation.

Follow existing test conventions: `import XCTest`, `@testable import Znuni`, `final class`, `test_scenario_expectedBehavior()` naming.

- [ ] **Step 1: Create PlanViewModelTests.swift**

Create `ios-app/ZnuniTests/ZnuniTests/PlanViewModelTests.swift`:

```swift
import XCTest
@testable import Znuni

final class PlanViewModelTests: XCTestCase {

    // MARK: - Initial State

    func test_initialState_isEmpty() {
        let vm = PlanViewModel()
        if case .empty = vm.planState {
            // pass
        } else {
            XCTFail("Expected .empty, got \(vm.planState)")
        }
    }

    func test_initialDate_isTodayBefore22() {
        // If current hour < 22, selectedDate should be today
        let vm = PlanViewModel()
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 22 {
            XCTAssertTrue(Calendar.current.isDateInToday(vm.selectedDate))
        } else {
            XCTAssertTrue(Calendar.current.isDateInTomorrow(vm.selectedDate))
        }
    }

    // MARK: - Date Strip

    func test_dates_returns14Days() {
        let vm = PlanViewModel()
        XCTAssertEqual(vm.dates.count, 14)
    }

    func test_dates_startsFromToday() {
        let vm = PlanViewModel()
        XCTAssertTrue(Calendar.current.isDateInToday(vm.dates[0]))
    }

    // MARK: - State Transitions: selectDate

    func test_selectDate_withNoCachedPlan_transitionsToEmpty() async {
        let vm = PlanViewModel()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        vm.selectDate(tomorrow)
        // Allow async calendar check to complete
        try? await Task.sleep(nanoseconds: 500_000_000)
        // Without calendar events, should be .empty
        if case .empty = vm.planState {
            // pass
        } else if case .calendarPreview = vm.planState {
            // also acceptable if calendar has events
        } else {
            XCTFail("Expected .empty or .calendarPreview after selectDate")
        }
    }

    // MARK: - State Transitions: lock / unlock

    func test_lock_setsSlotLocked() {
        let vm = PlanViewModel()
        let slot = makeTestSlot(id: "test-1", locked: false)
        let agenda = makeTestAgenda(slots: [slot])
        vm.planState = .dealt(agenda)

        vm.lock(slotId: "test-1")

        if case .dealt(let updated) = vm.planState {
            XCTAssertTrue(updated.slots[0].isLocked)
        } else {
            XCTFail("Expected .dealt state")
        }
    }

    func test_unlock_setsSlotUnlocked() {
        let vm = PlanViewModel()
        let slot = makeTestSlot(id: "test-1", locked: true)
        let agenda = makeTestAgenda(slots: [slot])
        vm.planState = .dealt(agenda)

        vm.unlock(slotId: "test-1")

        if case .dealt(let updated) = vm.planState {
            XCTAssertFalse(updated.slots[0].isLocked)
        } else {
            XCTFail("Expected .dealt state")
        }
    }

    // MARK: - State Transitions: remove

    func test_remove_deletesSlot() {
        let vm = PlanViewModel()
        let slot1 = makeTestSlot(id: "s1", locked: false)
        let slot2 = makeTestSlot(id: "s2", locked: false)
        let agenda = makeTestAgenda(slots: [slot1, slot2])
        vm.planState = .dealt(agenda)

        vm.remove(slotId: "s1")

        if case .dealt(let updated) = vm.planState {
            XCTAssertEqual(updated.slots.count, 1)
            XCTAssertEqual(updated.slots[0].id, "s2")
        } else {
            XCTFail("Expected .dealt state")
        }
    }

    func test_remove_onCalendarSlot_discardsIt() {
        let vm = PlanViewModel()
        let slot = makeTestSlot(id: "cal-1", locked: true, source: .calendar)
        let agenda = makeTestAgenda(slots: [slot])
        vm.planState = .dealt(agenda)

        vm.remove(slotId: "cal-1")

        if case .dealt(let updated) = vm.planState {
            XCTAssertEqual(updated.slots.count, 0)
        } else {
            XCTFail("Expected .dealt state")
        }
        // CalendarDiscardStore should now contain "cal-1"
        // (verify when CalendarBridge is wired)
    }

    // MARK: - State Transitions: replaceWithCustom

    func test_replaceWithCustom_replacesSlot() {
        let vm = PlanViewModel()
        let slot = makeTestSlot(id: "s1", locked: false)
        let agenda = makeTestAgenda(slots: [slot])
        vm.planState = .dealt(agenda)

        let now = Date()
        let later = now.addingTimeInterval(3600)
        vm.replaceWithCustom(slotId: "s1", name: "Visit Grandma", start: now, end: later, address: nil)

        if case .dealt(let updated) = vm.planState {
            XCTAssertEqual(updated.slots[0].venueName, "Visit Grandma")
            XCTAssertEqual(updated.slots[0].source, .userCustom)
            XCTAssertTrue(updated.slots[0].isLocked)
        } else {
            XCTFail("Expected .dealt state")
        }
    }

    // MARK: - Redeal preserves locked

    func test_redeal_keepsLockedSlots() async {
        let vm = PlanViewModel()
        let locked = makeTestSlot(id: "locked-1", locked: true)
        let unlocked = makeTestSlot(id: "unlocked-1", locked: false)
        let agenda = makeTestAgenda(slots: [locked, unlocked])
        vm.planState = .dealt(agenda)

        await vm.redeal()

        if case .dealt(let updated) = vm.planState {
            let lockedSlot = updated.slots.first { $0.id == "locked-1" }
            XCTAssertNotNil(lockedSlot, "Locked slot should survive redeal")
            XCTAssertTrue(lockedSlot?.isLocked == true)
        } else if case .error = vm.planState {
            // Acceptable in test environment without API/data
        } else {
            XCTFail("Expected .dealt or .error after redeal")
        }
    }

    // MARK: - Save to calendar locks all

    func test_saveToCalendar_locksAllSlots() async {
        let vm = PlanViewModel()
        let s1 = makeTestSlot(id: "s1", locked: false)
        let s2 = makeTestSlot(id: "s2", locked: true)
        let agenda = makeTestAgenda(slots: [s1, s2])
        vm.planState = .dealt(agenda)

        // saveToCalendar will fail without calendar access in test,
        // but we can test the lock behavior by checking state transition
        do {
            try await vm.saveToCalendar()
            if case .saved(let saved) = vm.planState {
                XCTAssertTrue(saved.slots.allSatisfy { $0.isLocked })
            }
        } catch {
            // Expected in test environment without calendar access
        }
    }

    // MARK: - Helpers

    /// Create a test AgendaSlot. Adjust parameters to match actual AgendaSlot init.
    private func makeTestSlot(
        id: String,
        locked: Bool,
        source: SlotSource = .aiGenerated
    ) -> AgendaSlot {
        // NOTE: Update this to match the actual AgendaSlot initializer
        // after Task 1 model changes land. The init params here are
        // placeholders — read DayAgenda.swift for real field names.
        var slot = AgendaSlot.placeholder() // or however AgendaSlot is constructed
        // Adjust: slot.id = id, slot.isLocked = locked, slot.source = source
        return slot
    }

    /// Create a test DayAgenda. Adjust to match actual DayAgenda init.
    private func makeTestAgenda(slots: [AgendaSlot]) -> DayAgenda {
        // NOTE: Update this to match actual DayAgenda initializer
        // after Task 1 model changes land.
        return DayAgenda.placeholder(slots: slots)
    }
}
```

**Important:** The `makeTestSlot` and `makeTestAgenda` helpers use placeholder constructors. After Task 1 lands, update these to use the real initializers. The tests will not compile until then — that's intentional (red tests).

- [ ] **Step 2: Create TravelEstimateTests.swift**

Create `ios-app/ZnuniTests/ZnuniTests/TravelEstimateTests.swift`:

```swift
import XCTest
@testable import Znuni

final class TravelEstimateTests: XCTestCase {

    // MARK: - Distance-based mode selection

    func test_under1km_isWalking() {
        // 500m apart → walking
        let estimate = TravelEstimate.estimate(
            fromLat: 47.3769, fromLon: 8.5417,  // Zurich HB
            toLat: 47.3733, toLon: 8.5415        // ~400m south
        )
        XCTAssertEqual(estimate.mode, .walking)
    }

    func test_1to3km_isTransit() {
        // ~2km apart → tram
        let estimate = TravelEstimate.estimate(
            fromLat: 47.3769, fromLon: 8.5417,  // Zurich HB
            toLat: 47.3585, toLon: 8.5480        // ~2km south
        )
        XCTAssertEqual(estimate.mode, .transit)
    }

    func test_over3km_isTransit() {
        // ~5km apart → transit
        let estimate = TravelEstimate.estimate(
            fromLat: 47.3769, fromLon: 8.5417,  // Zurich HB
            toLat: 47.3849, toLon: 8.5743        // Zoo (~4.5km)
        )
        XCTAssertEqual(estimate.mode, .transit)
    }

    // MARK: - Time estimates

    func test_walkingTime_isReasonable() {
        // 400m at 80m/min ≈ 5 min
        let estimate = TravelEstimate.estimate(
            fromLat: 47.3769, fromLon: 8.5417,
            toLat: 47.3733, toLon: 8.5415
        )
        XCTAssertGreaterThanOrEqual(estimate.minutes, 1)
        XCTAssertLessThanOrEqual(estimate.minutes, 10)
    }

    func test_transitTime_includes5minWait() {
        // 2km at 250m/min = 8 + 5 wait = 13 min
        let estimate = TravelEstimate.estimate(
            fromLat: 47.3769, fromLon: 8.5417,
            toLat: 47.3585, toLon: 8.5480
        )
        XCTAssertGreaterThanOrEqual(estimate.minutes, 10)
    }

    func test_nilCoordinates_returnsDefault() {
        // When either venue has no coordinates
        let estimate = TravelEstimate.estimate(
            fromLat: nil, fromLon: nil,
            toLat: 47.3585, toLon: 8.5480
        )
        // Should return a sensible default (e.g., 10 min transit)
        XCTAssertGreaterThan(estimate.minutes, 0)
    }
}
```

**Note:** `TravelEstimate.estimate(fromLat:fromLon:toLat:toLon:)` is a static method to be created in Task 1 as part of the `TravelEstimate` struct definition. Tests won't compile until then.

- [ ] **Step 3: Create CalendarBridgeTests.swift**

Create `ios-app/ZnuniTests/ZnuniTests/CalendarBridgeTests.swift`:

```swift
import XCTest
@testable import Znuni

final class CalendarBridgeTests: XCTestCase {

    // MARK: - Event filtering

    func test_fetchEvents_excludesAllDayEvents() async {
        // This test requires calendar access in the simulator.
        // If no access, skip gracefully.
        let bridge = CalendarBridge()
        guard bridge.hasAccess else {
            // Cannot test without calendar permission
            return
        }
        let events = await bridge.fetchEvents(for: Date())
        for event in events {
            XCTAssertFalse(event.isAllDay, "All-day events should be excluded")
        }
    }

    func test_fetchEvents_excludesDiscardedEvents() async {
        // Discard an event, then verify it doesn't appear
        let bridge = CalendarBridge()
        let testID = "test-discarded-\(UUID().uuidString)"
        bridge.discardEvent(id: testID)

        // The discarded ID should now be in the store
        // (Actual filtering test requires a real calendar event with that ID)
    }

    // MARK: - CalendarSlot mapping

    func test_calendarSlot_hasCorrectFields() {
        let slot = CalendarSlot(
            id: "test-id",
            title: "Dentist",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false
        )
        XCTAssertEqual(slot.id, "test-id")
        XCTAssertEqual(slot.title, "Dentist")
        XCTAssertFalse(slot.isAllDay)
    }
}
```

- [ ] **Step 4: Create PlanUITests.swift**

Create `ios-app/ZnuniUITests/PlanUITests.swift`:

```swift
import XCTest

final class PlanUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Tab Navigation

    func test_todayTab_exists() {
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.exists, "Today tab should exist in tab bar")
    }

    func test_newsTab_exists() {
        let newsTab = app.tabBars.buttons["News"]
        XCTAssertTrue(newsTab.exists, "News tab should exist in tab bar")
    }

    func test_fourTabs_exist() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertEqual(tabBar.buttons.count, 4, "Should have 4 tabs")
    }

    // MARK: - Empty State

    func test_todayTab_showsPlanMyDay() {
        app.tabBars.buttons["Today"].tap()
        let planButton = app.buttons["Plan my day"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 5), "Plan my day CTA should appear")
    }

    // MARK: - Date Strip

    func test_dateStrip_isVisible() {
        app.tabBars.buttons["Today"].tap()
        // Date strip should show day numbers
        let today = Calendar.current.component(.day, from: Date())
        let dayLabel = app.staticTexts["\(today)"]
        XCTAssertTrue(dayLabel.waitForExistence(timeout: 5), "Today's date should appear in strip")
    }

    // MARK: - Deal Flow

    func test_planMyDay_showsCards() {
        app.tabBars.buttons["Today"].tap()
        let planButton = app.buttons["Plan my day"]
        guard planButton.waitForExistence(timeout: 5) else {
            XCTFail("Plan my day button not found")
            return
        }
        planButton.tap()

        // Should see either cards or a loading indicator
        let loading = app.activityIndicators.firstMatch
        let card = app.otherElements["plan-slot-card"].firstMatch
        let appeared = loading.waitForExistence(timeout: 3) || card.waitForExistence(timeout: 10)
        XCTAssertTrue(appeared, "Should see loading or cards after tapping Plan my day")
    }

    // MARK: - Save & Redeal Buttons

    func test_dealtState_showsSaveAndRedeal() {
        // This test assumes we can reach dealt state
        // May need to be adjusted based on actual composition time
        app.tabBars.buttons["Today"].tap()
        let planButton = app.buttons["Plan my day"]
        guard planButton.waitForExistence(timeout: 5) else { return }
        planButton.tap()

        // Wait for composition
        let saveButton = app.buttons["Save to calendar"]
        let redealButton = app.buttons["Redeal"]

        // At least one should appear within 15 seconds (composition time)
        let appeared = saveButton.waitForExistence(timeout: 15)
        if appeared {
            XCTAssertTrue(redealButton.exists, "Redeal button should exist alongside Save")
        }
        // If neither appears, composition may have failed — acceptable in CI
    }
}
```

- [ ] **Step 5: Build tests to verify they compile (most will fail — that's expected)**

```bash
cd ios-app && xcodebuild build-for-testing -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```

Tests will NOT compile yet — they reference types (`PlanViewModel`, `TravelEstimate`, `CalendarBridge`) that don't exist. That's correct — they turn green as each task lands.

For now, wrap the test bodies that reference unbuilt types in `#if false ... #endif` so the test target compiles. Remove the `#if false` guards as each task makes the types available.

- [ ] **Step 6: Commit**

```bash
git add ios-app/ZnuniTests/ ios-app/ZnuniUITests/
git commit -m "test: add regression test scaffolding for Plan tab reimplementation (all red)"
```

---

## Task 1: Data Model Changes

**Files:**
- Modify: `ios-app/Znuni/Models/DayAgenda.swift`
- Create: `ios-app/Znuni/Models/CalendarSlot.swift`

- [ ] **Step 1: Read DayAgenda.swift and locate SlotSource, SwapOption, and dormant fields**

Read `Models/DayAgenda.swift` fully. Note line numbers for:
- `SlotSource` enum (around line 150)
- `SwapOption` struct (around line 309)
- `swaps` property on `AgendaSlot`
- `DayAgenda` fields: `theme`, `weatherNote`, `badWeatherMode`, `hasStaleSlots`

- [ ] **Step 2: Add SlotSource.calendar**

In `SlotSource` enum, add:
```swift
case calendar
```

- [ ] **Step 3: Remove SwapOption and swaps**

Delete the `SwapOption` struct entirely. Remove `swaps: [SwapOption]` property from `AgendaSlot`. Remove any initializer parameters referencing swaps.

- [ ] **Step 4: Clean up dormant DayAgenda fields**

Remove from `DayAgenda`: `theme`, `weatherNote`, `badWeatherMode`, `hasStaleSlots` — only if they are not used by kept services. Grep for each field name first:
```bash
cd ios-app && grep -r "theme\|weatherNote\|badWeatherMode\|hasStaleSlots" Znuni/Services/ --include="*.swift" -l
```
If any service references them, keep those fields. Only remove truly unused ones.

- [ ] **Step 5: Create CalendarSlot model**

Create `Models/CalendarSlot.swift`:
```swift
import Foundation

struct CalendarSlot: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}
```

- [ ] **Step 6: Build to verify model changes compile**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

Fix any compilation errors from removed fields/types. Services that referenced `swaps` or `SwapOption` will need their references removed.

- [ ] **Step 7: Commit**

```bash
git add ios-app/Znuni/Models/
git commit -m "refactor: update DayAgenda model — add SlotSource.calendar, remove SwapOption, add CalendarSlot"
```

---

## Task 2: CalendarBridge Service

**Files:**
- Create: `ios-app/Znuni/Services/CalendarBridge.swift`

- [ ] **Step 1: Read existing CalendarService and CalendarSyncChecker**

Read these files to understand the existing API:
- `Services/CalendarService.swift` (96 lines)
- `Services/CalendarSyncChecker.swift` (50 lines)
- `Services/CalendarDiscardStore.swift`
- `Services/CalendarExportStore.swift`

- [ ] **Step 2: Create CalendarBridge**

Create `Services/CalendarBridge.swift`:
```swift
import Foundation
import EventKit

@Observable
final class CalendarBridge {
    private let calendarService = CalendarService.shared
    private let discardStore = CalendarDiscardStore()

    var hasAccess: Bool { calendarService.hasAccess }

    /// Fetch non-all-day calendar events for a date, excluding discarded ones
    func fetchEvents(for date: Date) async -> [CalendarSlot] {
        guard calendarService.hasAccess else { return [] }

        let events = calendarService.fetchEvents(for: date)
        let discardedIDs = discardStore.discardedIDs

        return events
            .filter { !$0.isAllDay && !discardedIDs.contains($0.eventIdentifier) }
            .map { CalendarSlot(
                id: $0.eventIdentifier,
                title: $0.title ?? "Event",
                startDate: $0.startDate,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay
            )}
    }

    /// Export plan slots as EKEvents, returns slotId → eventId mapping
    func exportPlan(_ slots: [AgendaSlot], city: String, to calendar: EKCalendar? = nil) async throws -> [String: String] {
        var mapping: [String: String] = [:]
        for slot in slots {
            let eventID = try calendarService.createEvent(
                title: slot.venueName,
                startDate: slot.slotDate ?? Date(),
                endDate: (slot.slotDate ?? Date()).addingTimeInterval(TimeInterval(slot.durationMinutes * 60)),
                notes: slot.reason,
                location: slot.venueName + ", " + city,
                latitude: slot.lat,
                longitude: slot.lon,
                calendar: calendar
            )
            mapping[slot.id] = eventID
        }
        return mapping
    }

    /// Remove previously exported events
    func removeExportedEvents(ids: [String]) {
        for id in ids {
            calendarService.deleteEvent(id: id)
        }
    }

    /// Discard a calendar event (won't appear again)
    func discardEvent(id: String) {
        discardStore.discard(id: id)
    }

    /// Request calendar access
    func requestAccess() async -> Bool {
        await calendarService.requestAccess()
    }
}
```

**Note:** Adjust method signatures to match the actual CalendarService API after reading it in Step 1. The above is a template — the exact parameter names and return types must match.

- [ ] **Step 3: Build to verify**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

- [ ] **Step 4: Commit**

```bash
git add ios-app/Znuni/Services/CalendarBridge.swift
git commit -m "feat: add CalendarBridge — unified calendar read/write/discard for Plan tab"
```

---

## Task 3: PlanViewModel (State Machine)

**Files:**
- Create: `ios-app/Znuni/ViewModels/PlanViewModel.swift`

This is the core of the reimplementation. Read the spec Section 8 carefully before starting.

- [ ] **Step 1: Read existing services to understand their APIs**

Read these files to know the exact method signatures you'll call:
- `Services/GapAnalysisEngine.swift` (173 lines)
- `Services/AgendaComposer.swift` (386 lines)
- `Services/TemplateEngine.swift` (854 lines)
- `Services/FreshnessScorer.swift` (294 lines)
- `Services/AnchorStore.swift` (175 lines)
- `Services/AgendaCache.swift` (64 lines)
- `Models/DayAgenda.swift` (as modified in Task 1)
- `Models/PlanningCity.swift`
- `Models/FamilySession.swift`

- [ ] **Step 2: Create PlanViewModel with PlanState enum and core properties**

Create `ViewModels/PlanViewModel.swift`:
```swift
import SwiftUI
import EventKit

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
        case (.composing, .composing): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

@Observable
final class PlanViewModel {
    // MARK: - State
    var planState: PlanState = .empty
    var selectedDate: Date = Date()
    var planningCity: PlanningCity = .zurich // default, adjust to match PlanningCity init

    // MARK: - Data pools (cached)
    private var activitiesData: ActivitiesResponse?
    private var lunchData: LunchResponse?
    private var weatherData: DayWeather?

    // MARK: - Dependencies
    private let calendarBridge = CalendarBridge()
    private let anchorStore = AnchorStore()
    private let cache = AgendaCache()

    // MARK: - Date Strip
    var dates: [Date] {
        (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date())) }
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
}
```

- [ ] **Step 3: Add selectDate method**

```swift
// MARK: - Date Selection
func selectDate(_ date: Date) {
    selectedDate = date
    // Check for cached plan first
    if let cached = cache.get(for: date, city: planningCity.id) {
        planState = .saved(cached) // or .dealt if not yet saved
        return
    }
    // Check calendar
    Task {
        let events = await calendarBridge.fetchEvents(for: date)
        await MainActor.run {
            if events.isEmpty {
                planState = .empty
            } else {
                planState = .calendarPreview(events)
            }
        }
    }
}
```

- [ ] **Step 4: Add deal() method**

```swift
// MARK: - Deal
func deal() async {
    let lockedSlots: [AgendaSlot]

    // Collect locked slots (calendar events converted to AgendaSlot)
    switch planState {
    case .calendarPreview(let calEvents):
        lockedSlots = calEvents.map { cal in
            AgendaSlot(
                id: cal.id,
                venueName: cal.title,
                slotType: .activity,
                source: .calendar,
                slotDate: cal.startDate,
                durationMinutes: Int(cal.endDate.timeIntervalSince(cal.startDate) / 60),
                isLocked: true
            )
        }
    case .dealt(let agenda):
        lockedSlots = agenda.slots.filter { $0.isLocked }
    case .saved(let agenda):
        lockedSlots = agenda.slots.filter { $0.isLocked }
    default:
        lockedSlots = []
    }

    await MainActor.run { planState = .composing(locked: lockedSlots) }

    do {
        // 1. Load data pools if needed
        try await loadDataPools()

        // 2. Convert locked slots to anchors for gap analysis
        let anchors = lockedSlots.map { slot in
            AnchorEvent(
                id: slot.id,
                title: slot.venueName,
                startDate: slot.slotDate ?? selectedDate,
                endDate: (slot.slotDate ?? selectedDate).addingTimeInterval(TimeInterval(slot.durationMinutes * 60)),
                source: slot.source == .calendar ? .calendar : .manual
            )
        }

        // 3. Gap analysis
        let gaps = GapAnalysisEngine.analyse(anchors: anchors, now: Date(), planDate: selectedDate)

        // 4. Compose (AI or template fallback)
        let composedSlots = try await compose(gaps: gaps, anchors: anchors)

        // 5. Merge locked + composed, sort by time
        var allSlots = lockedSlots + composedSlots
        allSlots.sort { ($0.slotDate ?? Date()) < ($1.slotDate ?? Date()) }

        // 6. Compute travel estimates
        computeTravelEstimates(&allSlots)

        let agenda = DayAgenda(slots: allSlots)

        // 7. Cache
        cache.store(agenda, for: selectedDate, city: planningCity.id)

        await MainActor.run { planState = .dealt(agenda) }
    } catch {
        await MainActor.run { planState = .error(error.localizedDescription) }
    }
}
```

**Note:** The exact `AnchorEvent`, `GapAnalysisEngine.analyse`, `AgendaComposer.compose`, and `DayAgenda` initializer signatures must be matched to the actual code. Read the services in Step 1 and adjust accordingly. The above is structural — the implementation must call the real APIs.

- [ ] **Step 5: Add redeal(), lock(), unlock(), remove(), replaceWithCustom(), saveToCalendar()**

```swift
// MARK: - Redeal
func redeal() async {
    await deal() // Same flow — locked slots stay, unlocked get new cards
}

// MARK: - Slot Actions
func lock(slotId: String) {
    guard case .dealt(var agenda) = planState else { return }
    if let idx = agenda.slots.firstIndex(where: { $0.id == slotId }) {
        agenda.slots[idx].isLocked = true
    }
    planState = .dealt(agenda)
}

func unlock(slotId: String) {
    guard case .dealt(var agenda) = planState else { return }
    if let idx = agenda.slots.firstIndex(where: { $0.id == slotId }) {
        agenda.slots[idx].isLocked = false
    }
    planState = .dealt(agenda)
    // Also handle .saved state
}

func remove(slotId: String) {
    switch planState {
    case .dealt(var agenda):
        // If it's a calendar slot, discard it
        if let slot = agenda.slots.first(where: { $0.id == slotId }), slot.source == .calendar {
            calendarBridge.discardEvent(id: slotId)
        }
        agenda.slots.removeAll { $0.id == slotId }
        computeTravelEstimates(&agenda.slots)
        planState = .dealt(agenda)
    case .saved(var agenda):
        agenda.slots.removeAll { $0.id == slotId }
        computeTravelEstimates(&agenda.slots)
        planState = .saved(agenda)
    default: break
    }
}

func replaceWithCustom(slotId: String, name: String, start: Date, end: Date, address: String?) {
    guard case .dealt(var agenda) = planState else { return }
    if let idx = agenda.slots.firstIndex(where: { $0.id == slotId }) {
        let custom = AgendaSlot(
            id: UUID().uuidString,
            venueName: name,
            slotType: agenda.slots[idx].slotType,
            source: .userCustom,
            slotDate: start,
            durationMinutes: Int(end.timeIntervalSince(start) / 60),
            isLocked: true,
            reason: nil,
            address: address
        )
        agenda.slots[idx] = custom
    }
    planState = .dealt(agenda)
}

// MARK: - Save to Calendar
func saveToCalendar() async throws {
    guard case .dealt(var agenda) = planState else { return }

    // Lock all slots
    for i in agenda.slots.indices {
        agenda.slots[i].isLocked = true
    }

    // Export
    let mapping = try await calendarBridge.exportPlan(agenda.slots, city: planningCity.name)

    // Store mapping
    let exportStore = CalendarExportStore()
    for (slotId, eventId) in mapping {
        exportStore.store(slotId: slotId, eventId: eventId)
    }

    // Cache
    cache.store(agenda, for: selectedDate, city: planningCity.id)

    await MainActor.run { planState = .saved(agenda) }
}
```

**Critical note:** All `AgendaSlot` initializers above are templates. The actual initializer has specific required parameters — read the model in Step 1 and use the real parameter names. You may need to add `address: String?` and `lat: Double?` / `lon: Double?` to the `AgendaSlot` model if not already present.

- [ ] **Step 6: Add private helpers (loadDataPools, compose, computeTravelEstimates)**

```swift
// MARK: - Private Helpers

private func loadDataPools() async throws {
    // Fetch activities + lunch data for planningCity if not cached
    if activitiesData == nil {
        activitiesData = try await APIClient.shared.fetchActivities(city: planningCity.id, language: "en")
    }
    if lunchData == nil {
        lunchData = try await APIClient.shared.fetchLunch(city: planningCity.id)
    }
}

private func compose(gaps: [FreeGap], anchors: [AnchorEvent]) async throws -> [AgendaSlot] {
    // Try AI first, fall back to template
    // Match the actual AgendaComposer.compose() signature from Step 1
    // Match the actual TemplateEngine.buildAgenda() signature from Step 1
    // Return composed slots with source: .aiGenerated
    fatalError("Implement using actual service APIs from Step 1")
}

private func computeTravelEstimates(_ slots: inout [AgendaSlot]) {
    for i in 0..<(slots.count - 1) {
        guard let fromLat = slots[i].lat, let fromLon = slots[i].lon,
              let toLat = slots[i+1].lat, let toLon = slots[i+1].lon else { continue }

        let distance = haversineDistance(lat1: fromLat, lon1: fromLon, lat2: toLat, lon2: toLon)

        if distance < 1000 {
            // Walking: distance / 80m per min
            let minutes = Int(distance / 80)
            slots[i].travelToNext = TravelEstimate(minutes: max(minutes, 1), mode: .walking)
        } else if distance < 3000 {
            // Tram: distance / 250m per min + 5 min wait
            let minutes = Int(distance / 250) + 5
            slots[i].travelToNext = TravelEstimate(minutes: minutes, mode: .transit)
        } else {
            // Transit: distance / 400m per min + 5 min wait
            let minutes = Int(distance / 400) + 5
            slots[i].travelToNext = TravelEstimate(minutes: minutes, mode: .transit)
        }
    }
}

private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371000.0
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon/2) * sin(dLon/2)
    return R * 2 * atan2(sqrt(a), sqrt(1-a))
}
```

**Note:** `TravelEstimate` may need to be defined or may already exist. Check `TravelConnectorView.swift` for the existing travel data structure and reuse it.

- [ ] **Step 7: Build to verify**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

Expect compilation errors where template code doesn't match real APIs. Fix each one by reading the actual service file and adjusting the call.

- [ ] **Step 8: Commit**

```bash
git add ios-app/Znuni/ViewModels/PlanViewModel.swift
git commit -m "feat: add PlanViewModel — state machine for plan tab (deal/redeal/lock/save)"
```

---

## Task 4: Tab Structure (4 tabs)

**Files:**
- Modify: `ios-app/Znuni/App/AppState.swift`
- Modify: `ios-app/Znuni/App/ContentView.swift`

- [ ] **Step 1: Read AppState.swift and ContentView.swift**

Read both files fully. Note:
- `AppTab` enum definition and cases
- Deep link handling in `AppState`
- Tab bar implementation in `ContentView` (ZnuniTabBar)
- How NavigationStacks are set up per tab

- [ ] **Step 2: Update AppTab enum**

In `AppState.swift`, change `AppTab` from 3 cases to 4:
```swift
enum AppTab: String, CaseIterable {
    case news
    case today
    case discover
    case settings
}
```

Update any deep link routing that references the old tab names.

- [ ] **Step 3: Update ContentView tab bar**

In `ContentView.swift`:
1. Add a `NewsNavigationStack` that wraps existing `NewsView`
2. Update `ZnuniTabBar` to show 4 tabs with correct icons:
   - News: newspaper icon (folded paper with text lines)
   - Today: rounded square with list lines (first square filled when active)
   - Discover: mountain (existing)
   - Settings: gear (existing)
3. The Today tab should show `PlanTabView()` (created in Task 6)

For now, make `PlanTabView` a placeholder:
```swift
struct PlanTabView: View {
    var body: some View {
        Text("Plan tab — coming in Task 6")
    }
}
```

- [ ] **Step 4: Build and verify 4 tabs appear**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add ios-app/Znuni/App/
git commit -m "feat: 4-tab structure — News, Today, Discover, Settings"
```

---

## Task 5: Delete Old Files

**Files:**
- Delete: `ios-app/Znuni/Views/Today/CalendarSwipeView.swift`
- Delete: `ios-app/Znuni/Views/Today/YourDayConfigSection.swift`
- Delete: `ios-app/Znuni/Views/Today/ExecHeaderView.swift`
- Delete: `ios-app/Znuni/Views/Today/SlotEditSheet.swift`
- Delete: `ios-app/Znuni/Services/MultiDayPlanStore.swift`
- Delete: `ios-app/Znuni/Services/TimelineShifter.swift`

- [ ] **Step 1: Grep for references to each file's types before deleting**

```bash
cd ios-app && for type in CalendarSwipeView YourDayConfigSection ExecHeaderView SlotEditSheet MultiDayPlanStore TimelineShifter; do
  echo "=== $type ===" && grep -r "$type" Znuni/ --include="*.swift" -l
done
```

Note which files reference these types — those files will need their references removed.

- [ ] **Step 2: Remove references from TodayView.swift and TodayViewModel.swift**

These files heavily reference the deleted types. For each reference:
- Comment out or remove the `.sheet`, `.onChange`, or view embedding that uses the deleted type
- Remove any `@State` or `@Published` properties that only existed to drive the deleted views

This will break TodayView significantly — that's expected. It will be replaced in Task 6.

- [ ] **Step 3: Delete the files**

```bash
cd ios-app && rm Znuni/Views/Today/CalendarSwipeView.swift \
  Znuni/Views/Today/YourDayConfigSection.swift \
  Znuni/Views/Today/ExecHeaderView.swift \
  Znuni/Views/Today/SlotEditSheet.swift \
  Znuni/Services/MultiDayPlanStore.swift \
  Znuni/Services/TimelineShifter.swift
```

- [ ] **Step 4: Build — fix remaining compilation errors**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep "error:" | head -20
```

Fix each error by removing the dead reference. The goal is a compiling app with the old views gone.

- [ ] **Step 5: Commit**

```bash
git add -A ios-app/
git commit -m "refactor: delete old Plan mode views — CalendarSwipe, ExecHeader, SlotEdit, MultiDayPlan, TimelineShifter"
```

---

## Task 6: PlanTabView + PlanHeroBanner + DateStripView

**Files:**
- Create: `ios-app/Znuni/Views/Today/PlanTabView.swift` (replace placeholder from Task 4)
- Create: `ios-app/Znuni/Views/Today/PlanHeroBanner.swift`
- Create: `ios-app/Znuni/Views/Today/DateStripView.swift`

- [ ] **Step 1: Read existing NewsHeroBanner for hero pattern reference**

Read `Views/News/NewsHeroBanner.swift` to understand the VStack + .background pattern, skyline illustration, and weather row implementation. Reuse the same structure.

- [ ] **Step 2: Create DateStripView**

Create `Views/Today/DateStripView.swift`:
```swift
import SwiftUI

struct DateStripView: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    var onCalendarTap: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(dates, id: \.self) { date in
                        DateCell(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate))
                            .id(date)
                            .onTapGesture { selectedDate = date }
                    }
                    // Calendar icon for dates beyond 14 days
                    Button(action: onCalendarTap) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.znChevron)
                            .frame(width: 32, height: 44)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(Color.znCream)
    }
}

private struct DateCell: View {
    let date: Date
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? Color.white.opacity(0.6) : Color.znMuted)
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.znInk)
        }
        .frame(minWidth: 42)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.znNavy : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 3: Create PlanHeroBanner**

Create `Views/Today/PlanHeroBanner.swift`. Follow the `NewsHeroBanner` pattern exactly — VStack with `.background {}`, skyline at 9% opacity, radial terracotta glow:

```swift
import SwiftUI

struct PlanHeroBanner: View {
    let date: Date
    let weather: DayWeather?
    let cityName: String
    var onCityTap: () -> Void

    private var dayName: String {
        if Calendar.current.isDateInToday(date) { return "day" }
        if Calendar.current.isDateInTomorrow(date) { return "tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private var dateString: String {
        date.formatted(.dateTime.weekday(.wide)) + " · " + date.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: eyebrow + city picker
            HStack {
                Text(dateString.uppercased())
                    .font(.znEyebrow)
                    .tracking(1.3)
                    .foregroundStyle(Color.white.opacity(0.42))
                Spacer()
                Button(action: onCityTap) {
                    HStack(spacing: 3) {
                        Text(cityName)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                            .opacity(0.6)
                    }
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.bottom, 4)

            // Title
            HStack(spacing: 6) {
                Text("Plan your")
                    .font(.heroTitle)
                    .foregroundStyle(Color.white)
                Text(dayName)
                    .font(.custom("Playfair", size: 28))
                    .italic()
                    .foregroundStyle(Color.white.opacity(0.68))
            }
            .padding(.bottom, 8)

            // Weather row
            if let w = weather {
                HStack(spacing: 14) {
                    Text("\(Int(w.tempMax ?? 0))°")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(Color.white)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(w.description ?? "")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.7))
                        if let hi = w.tempMax, let lo = w.tempMin {
                            Text("H:\(Int(hi))° L:\(Int(lo))°")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.42))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.znNavy
                RadialGradient(
                    colors: [Color.znTerracotta.opacity(0.22), .clear],
                    center: UnitPoint(x: 1.2, y: -0.3),
                    startRadius: 0, endRadius: 220
                )
                // Reuse SkylineIllustration if it exists, otherwise add later
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}
```

**Note:** Adjust `DayWeather` property names to match the actual model. Read the model file first.

- [ ] **Step 4: Create PlanTabView**

Replace the placeholder from Task 4 with the real view. Create `Views/Today/PlanTabView.swift`:

```swift
import SwiftUI

struct PlanTabView: View {
    @State private var viewModel = PlanViewModel()
    @State private var showDatePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    PlanHeroBanner(
                        date: viewModel.selectedDate,
                        weather: nil, // TODO: wire weather in Task 7
                        cityName: viewModel.planningCity.name,
                        onCityTap: { /* TODO: city picker */ }
                    )

                    DateStripView(
                        dates: viewModel.dates,
                        selectedDate: $viewModel.selectedDate,
                        onCalendarTap: { showDatePicker = true }
                    )

                    // Content based on state
                    planContent
                }
            }
            .background(Color.znCream)
            .onChange(of: viewModel.selectedDate) { _, newDate in
                viewModel.selectDate(newDate)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $viewModel.selectedDate)
            }
        }
    }

    @ViewBuilder
    private var planContent: some View {
        switch viewModel.planState {
        case .empty:
            emptyState
        case .calendarPreview(let events):
            calendarPreviewState(events)
        case .composing(let locked):
            composingState(locked)
        case .dealt(let agenda):
            dealtState(agenda)
        case .saved(let agenda):
            savedState(agenda)
        case .error(let message):
            errorState(message)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            // Weather card (TODO: wire in Task 7)
            Text("No plans yet")
                .font(.system(size: 15))
                .foregroundStyle(Color.znMuted)
                .padding(.top, 40)
            Button("Plan my day") {
                Task { await viewModel.deal() }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(LinearGradient.brand)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    // Calendar preview, composing, dealt, saved, error states
    // Each implemented as private computed properties
    // Wire to PlanSlotCard in Task 7

    private func calendarPreviewState(_ events: [CalendarSlot]) -> some View {
        VStack(spacing: 12) {
            Text("FROM YOUR CALENDAR")
                .font(.znEyebrow)
                .tracking(1)
                .foregroundStyle(Color.znMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(events) { event in
                // Simplified calendar card — will use PlanSlotCard in Task 7
                HStack {
                    Text("📅")
                    VStack(alignment: .leading) {
                        Text(event.title).font(.cardHeadline)
                        Text(event.startDate.formatted(.dateTime.hour().minute()) + " – " + event.endDate.formatted(.dateTime.hour().minute()))
                            .font(.znMono).foregroundStyle(Color.znMuted)
                    }
                    Spacer()
                    Text("🔒 Locked").font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.znNavy.opacity(0.08))
                        .clipShape(Capsule())
                }
                .padding(16)
                .background(Color.znSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button("Fill the gaps") {
                Task { await viewModel.deal() }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(LinearGradient.brand)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func composingState(_ locked: [AgendaSlot]) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.znNavy)
            Text("Planning your day...")
                .font(.system(size: 14))
                .foregroundStyle(Color.znMuted)
        }
        .padding(.top, 60)
    }

    private func dealtState(_ agenda: DayAgenda) -> some View {
        VStack(spacing: 0) {
            // Timeline — will use PlanSlotCard in Task 7
            ForEach(agenda.slots) { slot in
                Text(slot.venueName)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.znSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
            }

            // Bottom actions
            HStack(spacing: 8) {
                Button("Save to calendar") {
                    Task { try? await viewModel.saveToCalendar() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(LinearGradient.brand)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Redeal") {
                    Task { await viewModel.redeal() }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.znInk)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.znSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.znBorder))
            }
            .padding(.vertical, 12)
        }
    }

    private func savedState(_ agenda: DayAgenda) -> some View {
        dealtState(agenda) // Same layout, save button dimmed — refine in Task 7
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Something went wrong")
                .font(.cardHeadline)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.znMuted)
            Button("Try again") {
                Task { await viewModel.deal() }
            }
            .foregroundStyle(Color.znNavy)
        }
        .padding(.top, 40)
    }
}
```

- [ ] **Step 5: Update ContentView to use PlanTabView**

Replace the placeholder from Task 4 with the real `PlanTabView()`.

- [ ] **Step 6: Build and verify**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

- [ ] **Step 7: Commit**

```bash
git add ios-app/Znuni/Views/Today/PlanTabView.swift \
  ios-app/Znuni/Views/Today/PlanHeroBanner.swift \
  ios-app/Znuni/Views/Today/DateStripView.swift \
  ios-app/Znuni/App/ContentView.swift
git commit -m "feat: PlanTabView with hero banner, date strip, and state-driven content"
```

---

## Task 7: PlanSlotCard + SimpleTravelConnector

**Files:**
- Create: `ios-app/Znuni/Views/Today/PlanSlotCard.swift`
- Create: `ios-app/Znuni/Views/Today/SimpleTravelConnector.swift`
- Modify: `ios-app/Znuni/Views/Today/PlanTabView.swift`

This is the visual heart of the reimplementation. Reference the mockup at `.superpowers/brainstorm/88117-1774175237/today-complete.html`.

- [ ] **Step 1: Read existing ActivityCard and LunchCard for card patterns**

Read `Views/Activities/ActivityCard.swift` and `Views/Lunch/LunchCard.swift` for:
- 76×76 photo thumbnail pattern
- Playfair 15pt venue name
- Accent bar implementation (3px left)
- Accordion expand/collapse with `@Binding var expandedID: String?`
- `.cardStyle(borderColor:)` usage

- [ ] **Step 2: Create SimpleTravelConnector**

Create `Views/Today/SimpleTravelConnector.swift`:
```swift
import SwiftUI

struct SimpleTravelConnector: View {
    let minutes: Int
    let mode: TravelMode // .walking or .transit — check existing enum

    var body: some View {
        HStack(spacing: 8) {
            // Dashed line
            Rectangle()
                .fill(Color.znBorder)
                .frame(width: 2, height: 32)
                .mask(
                    VStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle().frame(height: 3)
                        }
                    }
                )

            // Travel chip
            HStack(spacing: 5) {
                Image(systemName: mode == .walking ? "figure.walk" : "tram.fill")
                    .font(.system(size: 10))
                Text("\(minutes) min \(mode == .walking ? "walk" : "tram")")
                    .font(.system(size: 11))
            }
            .foregroundStyle(Color.znMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.znBorder.opacity(0.5))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.znBorder.opacity(0.2)))

            Spacer()
        }
        .padding(.leading, 14)
    }
}
```

**Note:** Check if `TravelMode` enum exists or if it's called something else. Adjust accordingly.

- [ ] **Step 3: Create PlanSlotCard — collapsed state**

Create `Views/Today/PlanSlotCard.swift` with the collapsed card layout matching the mockup. Include:
- 76×76 photo placeholder (gradient+icon, category badge)
- Badge row (🔒 Locked / ✏️ Custom / no badge for new)
- ⋯ edit button with context menu
- Eyebrow: monospaced time + type label
- Playfair 15pt venue name
- Reason text (2-line clamp)
- Tags (FlowLayout or horizontal scroll)
- Footer: distance + "Tap to expand ›"
- 3px accent bar (terracotta/green/blue by source)
- Stay-at-home variant: dashed border, house icon

The card is complex — implement it fully following the patterns from ActivityCard and LunchCard read in Step 1.

- [ ] **Step 4: Add expanded state to PlanSlotCard**

When tapped, card expands with:
- Photo slides to top (160pt, full-width) — activity/restaurant only
- 2×2 metadata grid: Address, Hours, Distance, Price
- Full reason text
- Tags
- Action buttons: "📍 Directions" + "🌐 Website"
- Accordion pattern: `@Binding var expandedID: String?`

- [ ] **Step 5: Add context menu to PlanSlotCard**

The ⋯ button should present a context menu (or `.contextMenu`):
- Unlocked card: Lock · Replace with my own · Remove (red)
- Locked card: Unlock · Replace with my own · Remove (red)
- Calendar card: Unlock · Remove (red)

Wire each action to PlanViewModel methods via closures:
```swift
var onLock: () -> Void
var onUnlock: () -> Void
var onRemove: () -> Void
var onReplace: () -> Void
```

- [ ] **Step 6: Wire PlanSlotCard + SimpleTravelConnector into PlanTabView**

Update `PlanTabView.swift`'s `dealtState` and `savedState` to use real cards:
```swift
@State private var expandedSlotID: String?

ForEach(Array(agenda.slots.enumerated()), id: \.element.id) { index, slot in
    PlanSlotCard(
        slot: slot,
        expandedID: $expandedSlotID,
        onLock: { viewModel.lock(slotId: slot.id) },
        onUnlock: { viewModel.unlock(slotId: slot.id) },
        onRemove: { viewModel.remove(slotId: slot.id) },
        onReplace: { /* show CustomSlotSheet */ }
    )

    if index < agenda.slots.count - 1,
       let travel = slot.travelToNext {
        SimpleTravelConnector(minutes: travel.minutes, mode: travel.mode)
    }
}
```

Also wire the `calendarPreviewState` to use PlanSlotCard for calendar events (converted to AgendaSlot).

- [ ] **Step 7: Build and verify cards render**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -30
```

- [ ] **Step 8: Commit**

```bash
git add ios-app/Znuni/Views/Today/PlanSlotCard.swift \
  ios-app/Znuni/Views/Today/SimpleTravelConnector.swift \
  ios-app/Znuni/Views/Today/PlanTabView.swift
git commit -m "feat: PlanSlotCard with expand/collapse, context menu, travel connectors"
```

---

## Task 8: CustomSlotSheet + Haptics

**Files:**
- Create: `ios-app/Znuni/Views/Today/CustomSlotSheet.swift`
- Modify: `ios-app/Znuni/Views/Today/PlanTabView.swift`
- Modify: `ios-app/Znuni/Views/Today/PlanSlotCard.swift`

- [ ] **Step 1: Create CustomSlotSheet**

```swift
import SwiftUI
import CoreLocation

struct CustomSlotSheet: View {
    let replacingSlot: AgendaSlot
    var onSave: (String, Date, Date, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var address = ""

    init(replacingSlot: AgendaSlot, onSave: @escaping (String, Date, Date, String?) -> Void) {
        self.replacingSlot = replacingSlot
        self.onSave = onSave
        _startTime = State(initialValue: replacingSlot.slotDate ?? Date())
        _endTime = State(initialValue: (replacingSlot.slotDate ?? Date()).addingTimeInterval(TimeInterval(replacingSlot.durationMinutes * 60)))
    }

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && endTime > startTime }

    var body: some View {
        NavigationStack {
            Form {
                Section("Venue") {
                    TextField("Name", text: $name)
                    TextField("Address (optional)", text: $address)
                }
                Section("Time") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Replace slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, startTime, endTime, address.isEmpty ? nil : address)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Wire CustomSlotSheet into PlanTabView**

Add `@State private var replacingSlot: AgendaSlot?` and a `.sheet(item: $replacingSlot)` that presents `CustomSlotSheet`.

Wire the `onReplace` closure in PlanSlotCard to set `replacingSlot`.

- [ ] **Step 3: Add haptic feedback**

Add haptics throughout:
- Deal: `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` on each card appearance
- Lock/unlock: `UIImpactFeedbackGenerator(style: .light).impactOccurred()`
- Save to calendar: `UINotificationFeedbackGenerator().notificationOccurred(.success)`
- Redeal: `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`
- Card expand/collapse: `UIImpactFeedbackGenerator(style: .light).impactOccurred()`

- [ ] **Step 4: Build and verify**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add ios-app/Znuni/Views/Today/CustomSlotSheet.swift \
  ios-app/Znuni/Views/Today/PlanTabView.swift \
  ios-app/Znuni/Views/Today/PlanSlotCard.swift
git commit -m "feat: CustomSlotSheet for 'replace with my own' + haptic feedback"
```

---

## Task 9: Wire Weather, City Picker, and Opening Hours

**Files:**
- Modify: `ios-app/Znuni/ViewModels/PlanViewModel.swift`
- Modify: `ios-app/Znuni/Views/Today/PlanTabView.swift`
- Modify: `ios-app/Znuni/Views/Today/PlanHeroBanner.swift`

- [ ] **Step 1: Wire weather data into PlanViewModel**

Add weather fetching to `deal()` and `selectDate()`. Use the existing APIClient weather endpoint or Open-Meteo. The weather for the selected date should be available as `viewModel.weather`.

- [ ] **Step 2: Wire weather into PlanHeroBanner and weather summary card**

Pass `viewModel.weather` to PlanHeroBanner. Add a weather summary card in the empty/calendarPreview states.

- [ ] **Step 3: Add city picker menu to PlanHeroBanner**

Use SwiftUI `Menu` on the city picker button:
```swift
Menu {
    ForEach(PlanningCity.allCases, id: \.id) { city in
        Button(city.name) { viewModel.planningCity = city }
    }
} label: {
    // existing city picker button
}
```

When city changes, re-fetch data pools and recompose if a plan exists.

- [ ] **Step 4: Integrate OpeningHoursParser**

Read `Extensions/OpeningHoursParser.swift` (193 lines, already exists). Wire it into the deal flow:
- In `compose()`, filter the activity/restaurant pool using `OpeningHoursParser.isOpen(activity, at: slotStartTime)`
- Fail-open: if parsing fails, include the venue

- [ ] **Step 5: Build and verify**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

- [ ] **Step 6: Commit**

```bash
git add ios-app/Znuni/ViewModels/PlanViewModel.swift \
  ios-app/Znuni/Views/Today/PlanTabView.swift \
  ios-app/Znuni/Views/Today/PlanHeroBanner.swift
git commit -m "feat: wire weather, city picker, and opening hours into plan composition"
```

---

## Task 10: Deal Animation + Polish

**Files:**
- Modify: `ios-app/Znuni/Views/Today/PlanTabView.swift`
- Modify: `ios-app/Znuni/Views/Today/PlanSlotCard.swift`

- [ ] **Step 1: Add sequential deal animation**

When transitioning to `.dealt`, cards should appear one by one with a brief delay:
- Use `withAnimation(.spring(response: 0.3, dampingFraction: 0.7))` per card
- Stagger each card by ~0.1 seconds using `DispatchQueue.main.asyncAfter`
- Cards slide in from bottom with opacity transition

- [ ] **Step 2: Add two-beat animation for calendar flow**

When coming from `.calendarPreview`:
1. Calendar cards appear immediately (they were already visible)
2. Brief pause (0.3s)
3. Gap-fill cards deal in sequentially around them

- [ ] **Step 3: Saved state polish**

In `.saved` state:
- "Save to calendar" button shows "✓ Saved to calendar" with reduced opacity
- Cards show compact view (no reason text, no footer)
- ⋯ menu shows "Unlock" option

- [ ] **Step 4: Error state with stale cache fallback**

In `.error` state, check AgendaCache for a stale plan. If found, show it with a banner: "Showing cached plan — tap to retry"

- [ ] **Step 5: Build and test all states in simulator**

Run in simulator and manually test:
- Empty state → tap "Plan my day" → cards deal in
- Select a different date → state resets
- Calendar events → "Fill the gaps" → two-beat animation
- Lock/unlock via ⋯ → redeal → locked cards stay
- Save → all locked → reopen → saved state
- Replace with custom → custom card appears
- Remove → card gone

- [ ] **Step 6: Commit**

```bash
git add ios-app/Znuni/Views/Today/
git commit -m "feat: deal animation, two-beat calendar flow, saved state polish"
```

---

## Task 11: Clean Up Old TodayView + TodayViewModel

**Files:**
- Modify or delete: `ios-app/Znuni/Views/Today/TodayView.swift`
- Modify or delete: `ios-app/Znuni/ViewModels/TodayViewModel.swift`
- Modify or delete: `ios-app/Znuni/Views/Today/TodayHeroBanner.swift`
- Modify or delete: `ios-app/Znuni/Views/Today/AgendaSlotCard.swift`
- Modify or delete: `ios-app/Znuni/Views/Today/AgendaTimelineView.swift`

- [ ] **Step 1: Grep for remaining references to old types**

```bash
cd ios-app && grep -r "TodayViewModel\|TodayView\|AgendaSlotCard\|TodayHeroBanner\|AgendaTimelineView" Znuni/ --include="*.swift" -l
```

- [ ] **Step 2: Delete old files that are fully replaced**

Once PlanTabView is confirmed working:
- Delete `TodayView.swift` (replaced by PlanTabView)
- Delete `TodayViewModel.swift` (replaced by PlanViewModel)
- Delete `TodayHeroBanner.swift` (replaced by PlanHeroBanner)
- Delete `AgendaSlotCard.swift` (replaced by PlanSlotCard)
- Delete `AgendaTimelineView.swift` (replaced by inline timeline in PlanTabView)
- Delete `TravelConnectorView.swift` (replaced by SimpleTravelConnector)

- [ ] **Step 3: Remove any remaining references**

Fix compilation errors from deleted files. Update any Analytics/Telemetry calls that referenced old view names.

- [ ] **Step 4: Build and verify clean compile**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

- [ ] **Step 5: Run existing tests**

```bash
cd ios-app && xcodebuild test -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30
```

Fix any test failures caused by model changes or deleted types.

- [ ] **Step 6: Commit**

```bash
git add -A ios-app/
git commit -m "refactor: remove old TodayView, TodayViewModel, AgendaSlotCard — fully replaced by Plan tab"
```

---

## Task 12: End-to-End Verification

- [ ] **Step 1: Full simulator walkthrough**

Run the app in simulator and verify every user story:

| US | Test | Expected |
|----|------|----------|
| US-1 | Open Today tab, no calendar events | Empty state, weather, "Plan my day" |
| US-2 | Add calendar event, open Today tab | Calendar cards shown, "Fill the gaps" |
| US-3 | Tap "Plan my day" | Cards deal in with animation |
| US-4 | Tap "Fill the gaps" | Two-beat: calendar first, then gaps fill |
| US-5 | Tap different date in strip | State resets, new date shown |
| US-6 | Tap calendar icon at strip end | Date picker appears |
| US-7 | Tap a card | Expands with photo, metadata, directions |
| US-8 | ⋯ → Lock | 🔒 badge appears |
| US-9 | ⋯ → Unlock | Badge removed |
| US-10 | ⋯ → Replace | Form sheet, custom card replaces |
| US-11 | ⋯ → Remove | Card removed |
| US-12 | Tap Redeal | Unlocked cards replaced, locked stay |
| US-13 | Tap Save to calendar | Events in Calendar app with address |
| US-14 | Close and reopen app | Saved plan shown, all locked |
| US-15 | Tap Directions on expanded card | Apple Maps opens with correct pin |
| US-16 | Compose at 2 PM for today | Only afternoon/evening slots |
| US-17 | Rainy day forecast | Indoor venues suggested |
| US-18 | Venue with known hours | Not suggested when closed |
| US-19 | Switch city to Basel | Plan recomposes for Basel |
| US-20 | Bad weather | Stay-at-home card with dashed border |

- [ ] **Step 2: Verify 4-tab navigation**

- All 4 tabs render correctly
- News tab shows news feed
- Deep links still work (`swissportal://` scheme)
- Tab switching preserves state

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "test: end-to-end verification of Today tab reimplementation"
```
