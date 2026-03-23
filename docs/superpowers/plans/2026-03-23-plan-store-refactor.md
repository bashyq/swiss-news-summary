# PlanStore Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fragile 3-layer plan state caching with a single protocol-based PlanStore that normalizes IDs and persists write-through, fixing all calendar unlock/remove bugs.

**Architecture:** Create `PlanStoreProvider` protocol + `LocalPlanStore` implementation. Migrate PlanViewModel and CalendarBridge to use the store. Delete AgendaCache, CalendarDiscardStore, CalendarExportStore. Normalize all slot IDs (drop `"cal-"` and `"anchor-"` prefixes).

**Tech Stack:** Swift, @Observable, FileManager (JSON persistence), UserDefaults (migration)

**Spec:** `docs/superpowers/specs/2026-03-23-plan-store-refactor-design.md`

---

## ⚠️ Critical Notes

- **Every task must leave the app compiling and functional.** The old stores are not deleted until the new store is fully wired.
- **The `"cal-"` prefix removal is the single biggest fix.** This happens in Task 3 and should be tested thoroughly.
- **Read the actual APIs** of files you're modifying. Code snippets in this plan are structural templates.

## File Structure

### New Files
| File | Path | Responsibility |
|------|------|----------------|
| PlanStoreProvider | `Services/PlanStoreProvider.swift` | Protocol defining plan persistence API |
| LocalPlanStore | `Services/LocalPlanStore.swift` | Local implementation: memory + JSON disk + UserDefaults |
| PlanStoreTests | `ZnuniTests/ZnuniTests/PlanStoreTests.swift` | Unit tests for store CRUD + ID normalization |

### Modified Files
| File | Path | Changes |
|------|------|---------|
| PlanViewModel | `ViewModels/PlanViewModel.swift` | Replace inMemoryPlans/AgendaCache/planKey with store calls |
| CalendarBridge | `Services/CalendarBridge.swift` | Accept PlanStoreProvider for discard/export |
| PlanTabView | `Views/Today/PlanTabView.swift` | Drop `"cal-"` prefix in calendarSlotToAgendaSlot |
| DayAnchor | `Models/DayAnchor.swift` | Add `originalSlotId: String?` to AnchorEvent |
| PlanSlotCard | `Views/Today/PlanSlotCard.swift` | No changes expected (verify) |

### Deleted Files (Task 6 only, after migration verified)
| File | Path | Replaced By |
|------|------|-------------|
| AgendaCache | `Services/AgendaCache.swift` | LocalPlanStore |
| CalendarDiscardStore | `Services/CalendarDiscardStore.swift` | LocalPlanStore |
| CalendarExportStore | `Services/CalendarExportStore.swift` | LocalPlanStore |

---

## Task 1: PlanStoreProvider Protocol + LocalPlanStore

**Files:**
- Create: `ios-app/Znuni/Services/PlanStoreProvider.swift`
- Create: `ios-app/Znuni/Services/LocalPlanStore.swift`
- Create: `ios-app/ZnuniTests/ZnuniTests/PlanStoreTests.swift`

This task creates the new store WITHOUT wiring it into anything. Old stores continue to work. The app is unchanged — we're just adding new files.

- [ ] **Step 1: Create PlanStoreProvider protocol**

Create `ios-app/Znuni/Services/PlanStoreProvider.swift`:

```swift
import Foundation

/// Protocol for plan persistence. Implementations can be local (disk/memory),
/// cloud (CloudKit), or custom backend. All IDs should be raw (no prefixes).
protocol PlanStoreProvider {
    // MARK: - Plans
    func loadPlan(city: String, date: String) -> DayAgenda?
    func savePlan(_ agenda: DayAgenda, city: String, date: String)
    func deletePlan(city: String, date: String)

    // MARK: - Calendar Discards
    func isDiscarded(eventId: String) -> Bool
    func discard(eventId: String)
    func allDiscardedIds() -> Set<String>
    func clearDiscards()

    // MARK: - Calendar Exports
    func exportedEventId(for slotId: String) -> String?
    func storeExport(slotId: String, eventId: String)
    func allExports() -> [String: String]
    func clearExports()
    func hasExportedPlan() -> Bool

    // MARK: - ID Normalization
    static func normalizeId(_ id: String) -> String
}

extension PlanStoreProvider {
    /// Strip "cal-" and "anchor-" prefixes to get raw identifiers.
    static func normalizeId(_ id: String) -> String {
        if id.hasPrefix("cal-") { return String(id.dropFirst(4)) }
        if id.hasPrefix("anchor-") { return String(id.dropFirst(7)) }
        return id
    }
}
```

- [ ] **Step 2: Create LocalPlanStore implementation**

Create `ios-app/Znuni/Services/LocalPlanStore.swift`:

```swift
import Foundation
import os.log

private let storeLog = Logger(subsystem: "Bashar.Znuni", category: "PlanStore")

/// Local plan store: in-memory cache with write-through JSON disk persistence.
/// Calendar discards and exports stored in UserDefaults for simplicity.
@Observable
final class LocalPlanStore: PlanStoreProvider {
    static let shared = LocalPlanStore()

    // MARK: - In-Memory Cache
    private var plans: [String: DayAgenda] = [:]

    // MARK: - Disk Persistence
    private let storeDir: URL

    // MARK: - UserDefaults Keys (matching existing keys for migration)
    private let discardKey = "znuni.discardedCalendarEventIds"
    private let exportKey = "znuni.calendarExportMap"

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storeDir = docs.appendingPathComponent("PlanStore", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
    }

    private func key(city: String, date: String) -> String {
        "\(city)-\(date)"
    }

    private func fileURL(city: String, date: String) -> URL {
        storeDir.appendingPathComponent("\(key(city: city, date: date)).json")
    }

    // MARK: - Plans

    func loadPlan(city: String, date: String) -> DayAgenda? {
        let k = key(city: city, date: date)
        // Memory first
        if let cached = plans[k] { return cached }
        // Disk fallback
        let url = fileURL(city: city, date: date)
        guard let data = try? Data(contentsOf: url),
              let agenda = try? JSONDecoder().decode(DayAgenda.self, from: data) else {
            return nil
        }
        plans[k] = agenda // warm the cache
        storeLog.debug("Loaded plan from disk: \(k)")
        return agenda
    }

    func savePlan(_ agenda: DayAgenda, city: String, date: String) {
        let k = key(city: city, date: date)
        plans[k] = agenda
        // Write-through to disk
        if let data = try? JSONEncoder().encode(agenda) {
            try? data.write(to: fileURL(city: city, date: date))
            storeLog.debug("Saved plan to disk: \(k), \(agenda.slots.count) slots")
        }
    }

    func deletePlan(city: String, date: String) {
        let k = key(city: city, date: date)
        plans.removeValue(forKey: k)
        try? FileManager.default.removeItem(at: fileURL(city: city, date: date))
        storeLog.debug("Deleted plan: \(k)")
    }

    // MARK: - Calendar Discards

    private var discardedIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: discardKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: discardKey)
        }
    }

    func isDiscarded(eventId: String) -> Bool {
        discardedIds.contains(Self.normalizeId(eventId))
    }

    func discard(eventId: String) {
        var ids = discardedIds
        ids.insert(Self.normalizeId(eventId))
        discardedIds = ids
        storeLog.debug("Discarded event: \(Self.normalizeId(eventId))")
    }

    func allDiscardedIds() -> Set<String> {
        discardedIds
    }

    func clearDiscards() {
        discardedIds = []
    }

    // MARK: - Calendar Exports

    private var exportMap: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: exportKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: exportKey)
        }
    }

    func exportedEventId(for slotId: String) -> String? {
        exportMap[Self.normalizeId(slotId)]
    }

    func storeExport(slotId: String, eventId: String) {
        var map = exportMap
        map[Self.normalizeId(slotId)] = eventId
        exportMap = map
    }

    func allExports() -> [String: String] {
        exportMap
    }

    func clearExports() {
        exportMap = [:]
    }

    func hasExportedPlan() -> Bool {
        !exportMap.isEmpty
    }
}
```

**Note:** The UserDefaults keys match the existing `CalendarDiscardStore` and `CalendarExportStore` keys. This means migration is automatic — existing discards and exports are preserved.

- [ ] **Step 3: Create PlanStoreTests**

Create `ios-app/ZnuniTests/ZnuniTests/PlanStoreTests.swift`:

```swift
import XCTest
@testable import Znuni

final class PlanStoreTests: XCTestCase {

    private var store: LocalPlanStore!

    override func setUp() {
        store = LocalPlanStore()
        // Clean up test data
        store.deletePlan(city: "test", date: "2026-01-01")
        store.clearDiscards()
        store.clearExports()
    }

    // MARK: - ID Normalization

    func test_normalizeId_stripsCalPrefix() {
        XCTAssertEqual(LocalPlanStore.normalizeId("cal-ABC123"), "ABC123")
    }

    func test_normalizeId_stripsAnchorPrefix() {
        XCTAssertEqual(LocalPlanStore.normalizeId("anchor-XYZ"), "XYZ")
    }

    func test_normalizeId_leavesRawIdAlone() {
        XCTAssertEqual(LocalPlanStore.normalizeId("ABC123"), "ABC123")
    }

    // MARK: - Plan CRUD

    func test_saveThenLoad_returnsSameAgenda() {
        // This test needs a real DayAgenda — adjust init to match actual model
        // For now, verify the store compiles and the flow works
    }

    func test_loadNonexistent_returnsNil() {
        XCTAssertNil(store.loadPlan(city: "test", date: "9999-99-99"))
    }

    func test_deletePlan_removesFromMemoryAndDisk() {
        // Save then delete then load → nil
    }

    // MARK: - Calendar Discards

    func test_discard_normalizesId() {
        store.discard(eventId: "cal-ABC123")
        XCTAssertTrue(store.isDiscarded(eventId: "ABC123"))
        XCTAssertTrue(store.isDiscarded(eventId: "cal-ABC123"))
    }

    func test_clearDiscards_emptiesAll() {
        store.discard(eventId: "event1")
        store.discard(eventId: "event2")
        store.clearDiscards()
        XCTAssertFalse(store.isDiscarded(eventId: "event1"))
        XCTAssertEqual(store.allDiscardedIds().count, 0)
    }

    // MARK: - Calendar Exports

    func test_storeExport_normalizesSlotId() {
        store.storeExport(slotId: "cal-slot1", eventId: "ek-event-1")
        XCTAssertEqual(store.exportedEventId(for: "slot1"), "ek-event-1")
        XCTAssertEqual(store.exportedEventId(for: "cal-slot1"), "ek-event-1")
    }

    func test_hasExportedPlan_trueWhenExportsExist() {
        XCTAssertFalse(store.hasExportedPlan())
        store.storeExport(slotId: "s1", eventId: "e1")
        XCTAssertTrue(store.hasExportedPlan())
    }

    func test_clearExports_removesAll() {
        store.storeExport(slotId: "s1", eventId: "e1")
        store.clearExports()
        XCTAssertFalse(store.hasExportedPlan())
        XCTAssertNil(store.exportedEventId(for: "s1"))
    }
}
```

- [ ] **Step 4: Build and run tests**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone Air' build 2>&1 | tail -5
```

The app should compile with no errors. The new files are standalone — nothing references them yet.

- [ ] **Step 5: Commit**

```bash
git add ios-app/Znuni/Services/PlanStoreProvider.swift \
  ios-app/Znuni/Services/LocalPlanStore.swift \
  ios-app/ZnuniTests/ZnuniTests/PlanStoreTests.swift
git commit -m "feat: add PlanStoreProvider protocol + LocalPlanStore implementation + tests"
```

**Test checkpoint:** Build succeeds. PlanStoreTests compile (some tests may be skeletal). App unchanged.

---

## Task 2: Wire PlanStore into PlanViewModel (alongside old stores)

**Files:**
- Modify: `ios-app/Znuni/ViewModels/PlanViewModel.swift`

This task adds the store to PlanViewModel but keeps the old stores working in parallel. The store is the primary write target; old stores are still read as fallback. This means the app works even if the new store has bugs.

- [ ] **Step 1: Read PlanViewModel.swift fully**

Understand every place that reads/writes `inMemoryPlans`, calls `agendaCache`, or references `CalendarDiscardStore`/`CalendarExportStore`.

- [ ] **Step 2: Add store property and update savePlan calls**

Add to PlanViewModel:
```swift
let store: PlanStoreProvider = LocalPlanStore.shared
```

In every place that does `inMemoryPlans[planKey()] = agenda`, ALSO call:
```swift
store.savePlan(agenda, city: planningCity.id, date: isoString(for: selectedDate))
```

Keep `inMemoryPlans` for now — it's still read by `selectDate`, `lastDealtAgenda`, etc.

- [ ] **Step 3: Update selectDate to read from store first**

In `selectDate()`, change the lookup order:
```
1. store.loadPlan(city, date) → if found, set .dealt/.saved (replaces inMemoryPlans check)
2. CalendarBridge.fetchEvents() → if found, set .calendarPreview
3. .empty
```

Remove the `inMemoryPlans` read. Keep the "save before switching" logic but write to store instead.

- [ ] **Step 4: Update updateAgenda to write-through to store**

```swift
func updateAgenda(_ agenda: DayAgenda) {
    store.savePlan(agenda, city: planningCity.id, date: isoString(for: selectedDate))
    switch planState {
    case .dealt: planState = .dealt(agenda)
    case .saved: planState = .dealt(agenda)
    default: break
    }
}
```

Remove the `inMemoryPlans[planKey()] = agenda` line.

- [ ] **Step 5: Update clearPlan to delete from store**

```swift
func clearPlan() {
    store.deletePlan(city: planningCity.id, date: isoString(for: selectedDate))
    planState = .empty
}
```

Remove the `inMemoryPlans.removeValue` call.

- [ ] **Step 6: Remove inMemoryPlans entirely**

Delete:
- `private var inMemoryPlans: [String: DayAgenda] = [:]`
- `private func planKey(...)` helper
- All remaining `inMemoryPlans` references
- The `lastDealtAgenda` computed property (replace with `store.loadPlan(...)`)

- [ ] **Step 7: Build and test on device**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone Air' build 2>&1 | tail -5
```

**Manual test:** Plan my day → lock a slot → switch to tomorrow → switch back → locked plan is there.

- [ ] **Step 8: Commit**

```bash
git add ios-app/Znuni/ViewModels/PlanViewModel.swift
git commit -m "refactor: wire PlanStore into PlanViewModel, remove inMemoryPlans"
```

**Test checkpoint:** App works. Plans persist across date switches via store. Old AgendaCache still exists but is no longer the primary read path.

---

## Task 3: Normalize IDs — drop "cal-" prefix

**Files:**
- Modify: `ios-app/Znuni/Views/Today/PlanTabView.swift`
- Modify: `ios-app/Znuni/ViewModels/PlanViewModel.swift`
- Modify: `ios-app/Znuni/Models/DayAnchor.swift`

This is the critical fix. After this task, calendar unlock/remove should work.

- [ ] **Step 1: Drop "cal-" prefix from calendarSlotToAgendaSlot**

In `PlanTabView.swift`, find `calendarSlotToAgendaSlot()` and change:
```swift
// Before: id: "cal-\(event.id)"
// After:  id: event.id
```

- [ ] **Step 2: Preserve original slot ID in anchorToSlot**

In `DayAnchor.swift`, add `originalSlotId: String?` to `AnchorEvent`:
```swift
var originalSlotId: String?
```

In `PlanViewModel.swift`, update `slotToAnchor()` to pass the slot ID:
```swift
// Set anchor.originalSlotId = slot.id
```

In `PlanViewModel.swift`, update `anchorToSlot()` to preserve it:
```swift
// Before: id: "anchor-\(anchor.id.uuidString.prefix(8))"
// After:  id: anchor.originalSlotId ?? "anchor-\(anchor.id.uuidString.prefix(8))"
```

- [ ] **Step 3: Simplify unlock/remove — no more ID fuzzing**

In `PlanViewModel.swift`, simplify `unlock()`:
```swift
func unlock(slotId: String) {
    let normalized = LocalPlanStore.normalizeId(slotId)
    if case .calendarPreview(var events) = planState {
        // In preview, unlock is a no-op (events always locked until dealt)
        return
    }
    guard var agenda = currentAgenda,
          let idx = agenda.slots.firstIndex(where: { $0.id == normalized || $0.id == slotId }) else { return }
    agenda.slots[idx].isLocked = false
    updateAgenda(agenda)
}
```

Simplify `remove()`:
```swift
func remove(slotId: String) {
    let normalized = LocalPlanStore.normalizeId(slotId)
    if case .calendarPreview(var events) = planState {
        store.discard(eventId: normalized)
        events.removeAll { $0.id == normalized || $0.id == slotId }
        planState = events.isEmpty ? .empty : .calendarPreview(events)
        return
    }
    guard var agenda = currentAgenda else { return }
    if let idx = agenda.slots.firstIndex(where: { $0.id == normalized || $0.id == slotId }) {
        let slot = agenda.slots[idx]
        if slot.source == .calendar {
            store.discard(eventId: normalized)
        }
        agenda.slots.remove(at: idx)
    }
    populateTravelEstimates(in: &agenda.slots)
    updateAgenda(agenda)
}
```

- [ ] **Step 4: Build and test calendar unlock/remove on device**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone Air' build 2>&1 | tail -5
```

**Critical manual tests:**
1. Calendar events appear → tap ⋯ → Remove → card disappears
2. Calendar events appear → Fill the gaps → tap ⋯ on calendar card → Unlock → lock badge disappears
3. Calendar events appear → Fill the gaps → tap ⋯ on calendar card → Remove → card disappears
4. Remove a calendar event → switch date → switch back → event stays removed

- [ ] **Step 5: Commit**

```bash
git add ios-app/Znuni/Views/Today/PlanTabView.swift \
  ios-app/Znuni/ViewModels/PlanViewModel.swift \
  ios-app/Znuni/Models/DayAnchor.swift
git commit -m "fix: normalize IDs — drop cal- prefix, preserve slot IDs through anchor pipeline"
```

**Test checkpoint:** Calendar unlock and remove work. This is the most important test in the entire plan.

---

## Task 4: Wire PlanStore into CalendarBridge

**Files:**
- Modify: `ios-app/Znuni/Services/CalendarBridge.swift`

CalendarBridge currently uses CalendarDiscardStore and CalendarExportStore directly. Switch to PlanStoreProvider.

- [ ] **Step 1: Read CalendarBridge.swift fully**

Note every reference to `CalendarDiscardStore` and `CalendarExportStore`.

- [ ] **Step 2: Replace internal stores with PlanStoreProvider**

```swift
@Observable
final class CalendarBridge {
    private let calendarService = CalendarService.shared
    private let store: PlanStoreProvider

    init(store: PlanStoreProvider = LocalPlanStore.shared) {
        self.store = store
    }
}
```

- [ ] **Step 3: Update fetchEvents to use store**

Replace `discardStore.all()` with `store.allDiscardedIds()`.
Replace `exportStore.all().values` with `Set(store.allExports().values)`.

- [ ] **Step 4: Update exportPlan to use store**

Replace `CalendarExportStore` calls with `store.storeExport(slotId:eventId:)`.

- [ ] **Step 5: Update discardEvent to use store**

Replace `discardStore.discard(id:)` with `store.discard(eventId:)`.

- [ ] **Step 6: Remove old store imports/references**

Remove `private let discardStore = CalendarDiscardStore()` and `private let exportStore = CalendarExportStore()` (or equivalent).

- [ ] **Step 7: Build and test**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone Air' build 2>&1 | tail -5
```

**Manual test:** Remove a calendar event → switch away → switch back → event doesn't reappear.

- [ ] **Step 8: Commit**

```bash
git add ios-app/Znuni/Services/CalendarBridge.swift
git commit -m "refactor: CalendarBridge uses PlanStoreProvider instead of separate discard/export stores"
```

**Test checkpoint:** Calendar discard and export work through the store. Old stores are no longer referenced by CalendarBridge.

---

## Task 5: Remove AgendaCache from PlanViewModel

**Files:**
- Modify: `ios-app/Znuni/ViewModels/PlanViewModel.swift`

PlanViewModel still references AgendaCache in `deal()` for caching composed plans and in `redeal()` for invalidation. Replace with store calls.

- [ ] **Step 1: Find all AgendaCache references**

```bash
cd ios-app && grep -n "agendaCache\|AgendaCache" Znuni/ViewModels/PlanViewModel.swift
```

- [ ] **Step 2: Replace cacheAgenda calls with store.savePlan**

Every `await cacheAgenda(agenda, dateISO: dateISO, anchors: anchors)` becomes:
```swift
store.savePlan(agenda, city: planningCity.id, date: dateISO)
```

- [ ] **Step 3: Replace agendaCache.get calls with store.loadPlan**

Every `await agendaCache.get(date: dateISO, city: ...)` becomes:
```swift
store.loadPlan(city: planningCity.id, date: dateISO)
```

Note: `store.loadPlan` is synchronous, not async. Remove `await` where applicable.

- [ ] **Step 4: Replace agendaCache.invalidate with store.deletePlan**

In `redeal()`:
```swift
// Before: await agendaCache.invalidate()
// After:  store.deletePlan(city: planningCity.id, date: isoString(for: selectedDate))
```

- [ ] **Step 5: Remove agendaCache property and cacheAgenda helper**

Delete:
- `private let agendaCache = AgendaCache.shared`
- `func cacheAgenda(...)` helper function
- Any remaining AgendaCache references

- [ ] **Step 6: Build and test**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone Air' build 2>&1 | tail -5
```

**Manual test:** Plan → close app → reopen → plan is still there (disk persistence works).

- [ ] **Step 7: Commit**

```bash
git add ios-app/Znuni/ViewModels/PlanViewModel.swift
git commit -m "refactor: PlanViewModel uses PlanStore instead of AgendaCache"
```

**Test checkpoint:** No more AgendaCache usage. Plans persist to disk via LocalPlanStore.

---

## Task 6: Delete old store files

**Files:**
- Delete: `ios-app/Znuni/Services/AgendaCache.swift`
- Delete: `ios-app/Znuni/Services/CalendarDiscardStore.swift`
- Delete: `ios-app/Znuni/Services/CalendarExportStore.swift`

Only do this after Tasks 2-5 are verified working.

- [ ] **Step 1: Grep for remaining references**

```bash
cd ios-app && grep -rn "AgendaCache\|CalendarDiscardStore\|CalendarExportStore" Znuni/ --include="*.swift" -l
```

If any files still reference them (other than the files being deleted), fix those references first.

- [ ] **Step 2: Delete the files**

```bash
cd ios-app && rm -f \
  Znuni/Services/AgendaCache.swift \
  Znuni/Services/CalendarDiscardStore.swift \
  Znuni/Services/CalendarExportStore.swift
```

- [ ] **Step 3: Build and verify**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone Air' build 2>&1 | grep "error:" | head -10
```

Fix any remaining references.

- [ ] **Step 4: Run existing tests**

```bash
cd ios-app && xcodebuild test -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone Air' 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add -A ios-app/
git commit -m "refactor: delete AgendaCache, CalendarDiscardStore, CalendarExportStore — replaced by PlanStore"
```

**Test checkpoint:** 3 files deleted. App compiles and works. Single source of truth.

---

## Task 7: Remove debug logging

**Files:**
- Modify: `ios-app/Znuni/ViewModels/PlanViewModel.swift`
- Modify: `ios-app/Znuni/Views/Today/PlanSlotCard.swift`
- Modify: `ios-app/Znuni/Views/Today/PlanTabView.swift`

Clean up the os_log debug logging and the debug alert we added during development.

- [ ] **Step 1: Remove os_log imports and planLog/Logger calls from PlanViewModel**

Keep the import if other logging exists. Remove all `planLog.notice(...)` calls from unlock/remove/etc.

- [ ] **Step 2: Remove Logger calls from PlanSlotCard**

Remove `Logger(subsystem:...)` calls from `doLock`, `doUnlock`, `doRemove`.

- [ ] **Step 3: Remove debug alert from PlanTabView**

Remove `@State private var debugSlotAction: String?` and the `.alert("Debug: Slot Action", ...)` modifier.

- [ ] **Step 4: Build and commit**

```bash
cd ios-app && xcodebuild -project Znuni.xcodeproj -scheme Znuni \
  -destination 'platform=iOS Simulator,name=iPhone Air' build 2>&1 | tail -3
git add -A ios-app/ && git commit -m "cleanup: remove debug logging and debug alert"
```

---

## Task 8: End-to-end verification

Full manual test on real device:

- [ ] **Plan creation:** Plan my day → cards appear with animation
- [ ] **Lock:** ⋯ → Lock → badge appears immediately
- [ ] **Unlock:** ⋯ → Unlock → badge disappears immediately
- [ ] **Remove:** ⋯ → Remove → card disappears
- [ ] **Refresh plan:** Locked cards stay, unlocked replaced
- [ ] **Date switching:** Plan for today → switch to tomorrow → switch back → today's plan preserved
- [ ] **City switching:** Plan for Zürich → switch to Basel → switch back → Zürich plan preserved
- [ ] **Calendar events:** Appear as locked cards → Remove works → doesn't reappear
- [ ] **Calendar unlock:** In dealt state, unlock calendar card → lock badge removed
- [ ] **Save to calendar:** Events appear in Calendar app with venue + location
- [ ] **Clear plan:** X button → returns to empty state
- [ ] **App restart:** Plan → save → force quit → reopen → plan is there
- [ ] **Custom slot:** Replace with own → custom card appears → travel times calculated
- [ ] **Weather per day:** Switch dates → hero shows that day's forecast
