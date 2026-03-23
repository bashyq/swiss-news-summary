# PlanStore Refactor — Design Spec

> **Date:** 2026-03-23
> **Status:** Draft
> **Goal:** Replace fragile 3-layer plan state caching with a single protocol-based PlanStore

---

## 1. Problem Statement

The current plan state is spread across 4 independent stores with inconsistent key formats and ID conventions:

| Store | Key Format | ID Format | Persistence |
|-------|-----------|-----------|-------------|
| `inMemoryPlans` | `"cityId-dateISO"` | AgendaSlot IDs (mixed: `"morning"`, `"cal-XXXX"`, `"anchor-XXXX"`) | Memory only — lost on process kill |
| `AgendaCache` | `"dateNoHyphens-city-sessionHash[-anchorsHash]"` | N/A (stores raw Data) | Disk (Caches dir) |
| `CalendarDiscardStore` | `"znuni.discardedCalendarEventIds"` | Raw EKEvent identifiers | UserDefaults |
| `CalendarExportStore` | `"znuni.calendarExportMap"` | SlotId → EKEventId mapping | UserDefaults |

This causes:
- **ID mismatches**: CalendarSlot uses raw `eventIdentifier`, AgendaSlot uses `"cal-\(eventIdentifier)"`, AnchorSlot uses `"anchor-\(uuid)"`. Unlock/remove can't find slots.
- **Cache key mismatches**: inMemoryPlans and AgendaCache use different key formats, causing stale/missing data on date/city switches.
- **State desync**: Mutations via `updateAgenda()` write to inMemoryPlans but not to AgendaCache disk. Plans modified after deal (lock/unlock) are lost on process kill.

## 2. Design

### PlanStoreProvider Protocol

```swift
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
}
```

All IDs are **raw** (no prefixes). Callers normalize before calling.

### LocalPlanStore Implementation

```swift
@Observable
final class LocalPlanStore: PlanStoreProvider {
    // In-memory cache (fast reads)
    private var plans: [String: DayAgenda] = [:]

    // Disk persistence (survives process kill)
    private let storeDir: URL  // ~/Documents/PlanStore/

    // Calendar state (UserDefaults — small, simple)
    private let discardKey = "znuni.discardedCalendarEventIds"
    private let exportKey = "znuni.calendarExportMap"
}
```

**Key format**: `"cityId-dateISO"` (e.g., `"zurich-2026-03-23"`) — same for memory and disk.

**Disk format**: JSON files at `PlanStore/<cityId>-<dateISO>.json`

**Write-through**: Every `savePlan` writes to memory AND disk. No lazy sync.

**Read**: Memory first, disk fallback, nil if neither.

### ID Normalization

One function, used everywhere:

```swift
static func normalizeId(_ id: String) -> String {
    if id.hasPrefix("cal-") { return String(id.dropFirst(4)) }
    if id.hasPrefix("anchor-") { return String(id.dropFirst(7)) }
    return id
}
```

Applied at:
- `calendarSlotToAgendaSlot()` — use raw ID, no `"cal-"` prefix
- `anchorToSlot()` — preserve original slot ID instead of generating `"anchor-XXXX"`
- `unlock()`/`remove()` — normalize before lookup
- `CalendarBridge.discardEvent()` — normalize before storing
- `CalendarBridge.exportPlan()` — normalize slot IDs in mapping

### What Gets Deleted

| File/Component | Replaced By |
|---------------|-------------|
| `inMemoryPlans` dict in PlanViewModel | `LocalPlanStore.plans` |
| `planKey()` helper in PlanViewModel | `LocalPlanStore` key generation |
| `AgendaCache` actor | `LocalPlanStore` disk persistence |
| `CalendarDiscardStore` | `LocalPlanStore.discard/isDiscarded` |
| `CalendarExportStore` | `LocalPlanStore.storeExport/exportedEventId` |
| ID stripping logic in `unlock()`/`remove()` | `normalizeId()` at boundaries |

### What Changes in PlanViewModel

```
Before:                          After:
─────────                        ──────
inMemoryPlans[key] = agenda  →   store.savePlan(agenda, city, date)
inMemoryPlans[key]           →   store.loadPlan(city, date)
agendaCache.get(...)         →   store.loadPlan(city, date)
agendaCache.store(...)       →   store.savePlan(agenda, city, date)
agendaCache.invalidate()     →   store.deletePlan(city, date)
calendarBridge.discardEvent  →   store.discard(normalizeId(id))
CalendarExportStore.store    →   store.storeExport(slotId, eventId)
```

PlanViewModel holds a `let store: PlanStoreProvider` (injected, defaults to `LocalPlanStore.shared`).

### What Changes in CalendarBridge

CalendarBridge currently wraps CalendarDiscardStore and CalendarExportStore. After refactor:
- Remove internal DiscardStore/ExportStore references
- Accept a `PlanStoreProvider` in init
- Use `store.isDiscarded()` when filtering events
- Use `store.allExports()` when filtering exported events
- `exportPlan()` writes to `store.storeExport()` instead of CalendarExportStore

### What Changes in PlanSlotCard / PlanTabView

**Nothing.** The views call `viewModel.lock()`, `viewModel.remove()`, etc. The ViewModel handles store interaction. Views don't know about the store.

### What Changes in calendarSlotToAgendaSlot

Remove `"cal-"` prefix:
```swift
// Before: id: "cal-\(event.id)"
// After:  id: event.id
```

This is the single biggest fix. All downstream ID matching just works.

### What Changes in anchorToSlot

Preserve original slot ID instead of generating a new one:
```swift
// Before: id: "anchor-\(anchor.id.uuidString.prefix(8))"
// After:  id: anchor.originalSlotId ?? "anchor-\(anchor.id.uuidString.prefix(8))"
```

Requires adding `originalSlotId: String?` to `AnchorEvent`.

## 3. Data Flow After Refactor

### selectDate()
```
1. store.loadPlan(city, date) → if found, set .dealt/.saved
2. CalendarBridge.fetchEvents(date) → if found, set .calendarPreview
3. Otherwise .empty
```

### deal()
```
1. Compose plan (AI or template)
2. store.savePlan(agenda, city, date)
3. Set .dealt(agenda)
```

### lock/unlock/remove
```
1. Get agenda from planState (not from store — live state)
2. Mutate slots
3. store.savePlan(updated, city, date) — write-through
4. Set planState = .dealt(updated)
```

### saveToCalendar
```
1. Lock all slots
2. CalendarBridge.exportPlan(slots) → store.storeExport() per slot
3. store.savePlan(agenda, city, date)
4. Set .saved(agenda)
```

### selectDate (switch away)
```
1. savePlan current agenda (already done on every mutation — no-op)
2. Load new date from store
```

No more "save before switching" logic — the store already has the latest state because every mutation writes through.

## 4. Migration

- Read existing `AgendaCache` files on first launch of new version
- Convert to new `PlanStore` format
- Delete old cache files
- Existing `CalendarDiscardStore` UserDefaults key stays the same (LocalPlanStore reads it)
- Existing `CalendarExportStore` UserDefaults key stays the same

Or: just start fresh. Plans are transient (daily) — losing cached plans is not a big deal.

## 5. Future: Sync Layer

The `PlanStoreProvider` protocol enables:

```swift
class CloudPlanStore: PlanStoreProvider {
    let local: LocalPlanStore      // offline-first
    let remote: CloudKitProvider   // sync

    func savePlan(...) {
        local.savePlan(...)        // immediate
        remote.enqueueSync(...)    // background
    }

    func loadPlan(...) -> DayAgenda? {
        local.loadPlan(...)        // fast local read
    }
}
```

Conflict resolution: last-write-wins with timestamp. Each plan carries a `modifiedAt: Date` field.

## 6. Files to Create

| File | Responsibility |
|------|---------------|
| `Services/PlanStoreProvider.swift` | Protocol definition |
| `Services/LocalPlanStore.swift` | Local implementation (memory + disk + UserDefaults) |

## 7. Files to Modify

| File | Changes |
|------|---------|
| `ViewModels/PlanViewModel.swift` | Replace inMemoryPlans/AgendaCache/planKey with store calls |
| `Services/CalendarBridge.swift` | Accept PlanStoreProvider, use for discard/export |
| `Views/Today/PlanTabView.swift` | Remove `calendarSlotToAgendaSlot` "cal-" prefix |
| `Models/DayAnchor.swift` | Add `originalSlotId: String?` to AnchorEvent |

## 8. Files to Delete

| File | Reason |
|------|--------|
| `Services/AgendaCache.swift` | Replaced by LocalPlanStore |
| `Services/CalendarDiscardStore.swift` | Absorbed into LocalPlanStore |
| `Services/CalendarExportStore.swift` | Absorbed into LocalPlanStore |

## 9. Testing

- `PlanStoreTests.swift` — test save/load/delete plans, discard/export CRUD, ID normalization
- Update `PlanViewModelTests.swift` — inject mock PlanStoreProvider for predictable testing
- Manual: plan → lock → switch date → switch back → plan preserved
- Manual: calendar event → remove → doesn't reappear
- Manual: save to calendar → events in Calendar app → re-save after edit updates them
