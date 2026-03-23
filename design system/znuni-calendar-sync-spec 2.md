# Znüni — Calendar Sync

---

## CONTEXT

Znüni is a SwiftUI iOS app for Zürich families. It has five tabs: Today, Activities, Explore, Weekend, Settings. The Today tab contains an AI-powered agenda composer that builds a full-day plan (morning activity, lunch, afternoon activity, dinner) around immovable user commitments called **anchors**. Anchors are stored in `AnchorStore` as `AnchorEvent` entries and passed to `GapAnalysisEngine`, which determines what planning slots remain. Claude then selects venues to fill those slots.

The app is fully built through Step 15 of the implementation plan. You are now implementing **Step 16: Calendar Sync** — a new feature, not a modification of existing logic.

**Files most relevant to this feature:**
- `AnchorEvent.swift` + `AnchorStore.swift` — the anchor system this feature extends
- `TodayView.swift` — where the Sync button and swipe trigger live
- `AgendaComposer.swift` — recompose is triggered after calendar events are accepted
- `AgendaCache.swift` — must be invalidated when new anchors are added
- `SettingsView.swift` — calendar settings section added here

Do not modify `GapAnalysisEngine`, `AgendaComposer`, or any existing anchor logic. Calendar anchors feed into the existing system unchanged.

---


---

## 1. OVERVIEW

Two-way EventKit (iOS native calendar) integration:

- **Read**: Detect calendar events on the planned day → swipe UI to accept/discard → accepted events become anchors
- **Write**: Save the composed plan to calendar (one event per slot), update automatically on slot swap

This builds on the existing `AnchorEvent` / `AnchorStore` system. Calendar events that are accepted become `AnchorEvent` entries with `source: .calendar`. No new planning infrastructure needed — the planner already knows how to build around anchors.

---

## 2. DATA MODEL CHANGES

### 2a. Add `source` to `AnchorEvent`

```swift
enum AnchorSource: String, Codable {
    case manual      // user entered via AnchorFormSheet
    case calendar    // imported from EventKit
    case cityEvent   // came from a Znüni CityEvent
}

// Add to AnchorEvent:
var source: AnchorSource        // default: .manual
var calendarEventId: String?    // EKEvent.eventIdentifier — set when source == .calendar
```

### 2b. Add `CalendarDiscardStore`

Persists the IDs of calendar events the user has explicitly discarded. These never resurface in the swipe screen.

```swift
class CalendarDiscardStore {
    private let key = "znuni.discardedCalendarEventIds"

    func discard(_ eventId: String)
    func isDiscarded(_ eventId: String) -> Bool
    func all() -> Set<String>
}
```

### 2c. Add `CalendarExportStore`

Tracks which EKEvent IDs were created by Znüni for each plan slot, so they can be updated on slot swap.

```swift
class CalendarExportStore {
    // key: slotId → EKEvent.eventIdentifier
    func store(slotId: String, eventId: String)
    func eventId(for slotId: String) -> String?
    func removeAll()   // called when plan is rebuilt from scratch
}
```

---

## 3. CALENDAR PERMISSION

Use `EKEventStore`. Request access on first Sync tap only — do not request on app launch.

```swift
class CalendarService {
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        // iOS 17+: use requestFullAccessToEvents()
        // iOS 16 and below: use requestAccess(to: .event)
        // Return true if granted
    }

    func fetchEvents(for date: Date) -> [EKEvent]   // filters out all-day events (isAllDay == true)
    func createEvent(_ event: EKEvent) throws -> String   // returns eventIdentifier
    func updateEvent(id: String, with slot: AgendaSlot) throws
    func deleteEvent(id: String) throws
}
```

Only read/write the user's default calendar unless they've selected a specific calendar in Settings (see §7).

---

## 4. READ FLOW — SWIPE SCREEN

### 4a. Trigger conditions

**Plan mode only.** Calendar sync only triggers when the user is in Plan sub-view — no reason to check in News mode. On Plan sub-view appear and on "Sync" button tap, run `CalendarSyncChecker`:

```swift
struct CalendarSyncChecker {
    static func newEvents(
        for date: Date,
        existingAnchors: [AnchorEvent],
        discardStore: CalendarDiscardStore,
        calendarService: CalendarService
    ) -> [EKEvent] {
        let events = calendarService.fetchEvents(for: date)
        let existingCalendarIds = Set(existingAnchors.compactMap { $0.calendarEventId })

        return events.filter { event in
            !existingCalendarIds.contains(event.eventIdentifier) &&   // not already an anchor
            !discardStore.isDiscarded(event.eventIdentifier)          // not previously discarded
        }
    }
}
```

If `newEvents` is empty → do nothing, go straight to plan as normal.
If `newEvents` is non-empty → present `CalendarSwipeView` modally.

**On second open (plan already built):** go straight to plan. `CalendarSyncChecker` still runs silently in background. If new events detected → show a slim banner at top of agenda: "New calendar event detected — [Sync]". Tapping Sync presents the swipe screen for only the new events.

### 4b. CalendarSwipeView

Full-screen modal. Stack of cards, one per `EKEvent`. Tinder-style swipe:

- **Swipe right** → accept → falls toward calendar icon (right side) → becomes anchor
- **Swipe left** → discard → falls toward trash icon (left side) → stored in `CalendarDiscardStore`

**Card content:**
- Event title (Playfair Display, 22px)
- Date + time range (DM Sans, 15px, muted)
- Calendar name (DM Sans, 12px, muted) — e.g. "Family"
- Duration chip — e.g. "2 hrs"

**Visual affordances:**
- Drag right: green tint overlay + calendar icon scales up on right
- Drag left: red tint overlay + trash icon scales up on left
- Card stack: next card visible behind at 95% scale, slight offset down

**After last card is swiped:**
- Brief "Building plan…" full-screen overlay (navy background, Playfair "Building your day" + spinner)
- Accepted events converted to `AnchorEvent` (see §4c)
- `AnchorStore` updated
- `AgendaCache` invalidated
- Plan recomposed with new anchors
- Modal dismissed → Today tab shows updated plan

**If all cards discarded:**
- Skip "Building plan…" if plan already existed and no anchors changed
- Dismiss modal → return to existing plan

### 4c. EKEvent → AnchorEvent conversion

```swift
extension EKEvent {
    func toAnchorEvent() -> AnchorEvent {
        AnchorEvent(
            id: UUID(),
            title: self.title ?? "Calendar event",
            category: inferCategory(from: self.title),   // see below
            startTime: self.startDate,
            durationMinutes: Int(self.endDate.timeIntervalSince(self.startDate) / 60),
            neighbourhood: nil,      // not available from EKEvent
            kreis: nil,
            sourceEventId: nil,
            source: .calendar,
            calendarEventId: self.eventIdentifier,
            createdDate: Date()
        )
    }
}
```

**Category inference from title (simple keyword match, EN + DE):**

```swift
func inferCategory(from title: String?) -> AnchorCategory {
    guard let t = title?.lowercased() else { return .other }
    // Food (EN + DE)
    let foodKeywords = ["lunch", "dinner", "brunch", "restaurant", "café",
                        "mittagessen", "abendessen", "znüni", "zvieri"]
    if foodKeywords.contains(where: { t.contains($0) }) { return .food }
    // Social (EN + DE)
    let socialKeywords = ["birthday", "party", "playdate",
                          "geburtstag", "spieldate", "feier"]
    if socialKeywords.contains(where: { t.contains($0) }) { return .social }
    // Activity (EN + DE)
    let activityKeywords = ["sport", "class", "gym", "swim", "football",
                            "training", "schwimmen", "turnen", "kurs"]
    if activityKeywords.contains(where: { t.contains($0) }) { return .activity }
    // Errand (EN + DE)
    let errandKeywords = ["appointment", "doctor", "errand", "shop",
                          "arzt", "einkaufen", "termin", "zahnarzt"]
    if errandKeywords.contains(where: { t.contains($0) }) { return .errand }
    return .other
}
```

Category inference is best-effort. User can edit the anchor via existing `AnchorFormSheet` after the fact if wrong.

### 4d. Conflict detection

After accepting events, before recomposing, check for anchor conflicts:

```swift
// Two anchors conflict if their time ranges overlap
func detectConflicts(anchors: [AnchorEvent]) -> [(AnchorEvent, AnchorEvent)] {
    // Return pairs of overlapping anchors
}
```

If conflicts found, show a single warning banner above the agenda after plan builds:

```
"⚠️ Kindercity and Birthday Party overlap — check your plan"
```

No auto-resolution. User resolves manually via existing anchor edit flow.

---

## 5. WRITE FLOW — SAVE TO CALENDAR

### 5a. Save button

Add a **"Save to Calendar"** button to the agenda in browsing mode. Placement: below the [Rebuild] [Sync] pill row.

```
[Rebuild]  [Sync]
[Save to Calendar]
```

"Save to Calendar" is a secondary action — style it as a ghost button (navy border, navy text, no fill). Only show it when a plan exists (not during loading state).

### 5b. On tap

Request EventKit write access if not already granted.

**Dependency: `slotDate: Date` on `AgendaSlot`.** `AgendaSlot` must have a stored `Date` property (`slotDate`) — not computed from the `time` String. If this property doesn't exist yet, add it as part of this feature (set when slots are created in `AgendaComposer` and `TemplateEngine` by combining the plan date with the time string).

For each slot in `agenda.slots` (include all by default):

```swift
func exportPlanToCalendar(agenda: DayAgenda) throws {
    // Remove previously exported events for this plan first
    calendarExportStore.all().forEach { try? calendarService.deleteEvent(id: $0) }
    calendarExportStore.removeAll()

    for slot in agenda.slots {
        let event = EKEvent(eventStore: ekStore)
        event.title = slot.venueName
        event.startDate = slot.slotDate           // stored Date property on AgendaSlot
        event.endDate = slot.slotDate.addingTimeInterval(Double(slot.durationMinutes) * 60)
        event.notes = slot.reason   // Claude's reasoning as calendar note
        event.calendar = ekStore.defaultCalendarForNewEvents

        let eventId = try calendarService.createEvent(event)
        calendarExportStore.store(slotId: slot.id, eventId: eventId)
    }
}
```

Show a brief confirmation toast: "Plan saved to Calendar ✓"

### 5c. Auto-update on slot swap

When the user swaps a slot in browsing mode, if the plan has been exported:

```swift
func handleSlotSwap(slot: AgendaSlot) {
    // ... existing swap logic ...

    // Update calendar event if exported
    if let eventId = calendarExportStore.eventId(for: slot.id) {
        try? calendarService.updateEvent(id: eventId, with: slot)
    }
}
```

Update: title (new venue name), start/end time, notes (new reason text). Silent — no toast on auto-update.

### 5d. Plan rebuild clears exported events

When the plan is rebuilt from scratch (Rebuild button, session change, anchor change), delete all previously exported calendar events and clear `CalendarExportStore`. The user must tap "Save to Calendar" again after rebuilding.

---

## 6. SYNC BUTTON

Add "Sync" pill alongside existing "Rebuild" button in the Today tab header/action area.

```swift
HStack(spacing: 12) {
    Button("Rebuild") { ... }   // existing
    Button("Sync") {
        Task { await handleCalendarSync() }
    }
}
```

"Sync" button style: matches "Rebuild" — same pill shape, same typography.

`handleCalendarSync()`:
1. Request calendar read access if not granted
2. Run `CalendarSyncChecker`
3. If new events found → present `CalendarSwipeView`
4. If no new events → show brief toast: "Calendar is up to date"

---

## 7. SETTINGS

Add a "Calendar" section to the existing Settings tab:

```
Calendar
  Default calendar     [Family ›]   ← picker for which calendar to read/write
  Clear discarded events  [button]  ← resets CalendarDiscardStore so discarded events can resurface
```

"Clear discarded events" is a destructive action — show a confirmation alert before executing.

---

## 8. IMPLEMENTATION SEQUENCE

Do in order. Each step independently testable.

**Step A — Permission + CalendarService**
- `CalendarService.swift` — `requestAccess()`, `fetchEvents(for:)`, `createEvent()`, `updateEvent()`, `deleteEvent()`
- `fetchEvents(for:)` must filter out all-day events (`!$0.isAllDay`) — they can't map to time-bound anchors
- Test: fetch today's events, print to console

**Step B — Data model additions**
- Add `source: AnchorSource` and `calendarEventId: String?` to `AnchorEvent`
- `CalendarDiscardStore.swift`
- `CalendarExportStore.swift`
- Test: discard an ID, verify it persists across app restart

**Step C — CalendarSyncChecker**
- `CalendarSyncChecker.swift` — filter logic
- Wire to `TodayView.onAppear` (silent check only — no UI yet)
- Test: add a calendar event for today, verify it appears in filtered results

**Step D — CalendarSwipeView**
- Swipe card UI — drag gesture, tint overlay, icon scale animation
- Card stack visual (next card behind at 95% scale)
- Accept → `toAnchorEvent()` conversion → `AnchorStore.add()`
- Discard → `CalendarDiscardStore.discard()`
- "Building plan…" overlay after last card
- Cache invalidation + recompose trigger
- Test: swipe through 3 events, verify anchors created for accepted ones only

**Step E — Trigger wiring**
- Plan sub-view appear (not News mode): run checker, present `CalendarSwipeView` if new events
- "New calendar event detected" banner for second-open case
- Test: build plan, add new calendar event, reopen app, switch to Plan, verify banner appears

**Step F — Conflict detection**
- `detectConflicts()` — post-accept check
- Warning banner on agenda view
- Test: accept two overlapping events, verify warning appears

**Step G — Write flow**
- "Save to Calendar" ghost button below pill row
- `exportPlanToCalendar()` — create one event per slot
- Confirmation toast
- Auto-update on slot swap
- Plan rebuild → clear exported events
- Test: save plan, verify 4 events in iOS Calendar app; swap a slot, verify calendar event updates

**Step H — Sync button + Settings**
- Add "Sync" pill next to "Rebuild"
- "Calendar is up to date" toast when no new events
- Settings: calendar picker + clear discarded events

---

## 9. WHAT DOES NOT CHANGE

- `AnchorStore` core methods — calendar anchors use the same add/remove/purge flow
- `GapAnalysisEngine` — calendar anchors are identical to manual anchors from its perspective
- `AgendaComposer` prompt — calendar anchors appear in the prompt via existing `AnchorEvent.promptDescription`
- `AnchorFormSheet` — user can edit calendar-sourced anchors via existing sheet if category inference is wrong
- All existing slot editing, swap, execution mode, and timeline shift logic
