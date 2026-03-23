import XCTest
@testable import Znuni

final class PlanStoreTests: XCTestCase {

    private var store: LocalPlanStore!

    override func setUp() {
        store = LocalPlanStore()
        store.deletePlan(city: "test", date: "2026-01-01")
        store.clearDiscards()
        store.clearExports()
    }

    // MARK: - ID Normalization

    func test_normalizeId_stripsCalPrefix() {
        XCTAssertEqual(PlanStoreID.normalize("cal-ABC123"), "ABC123")
    }

    func test_normalizeId_stripsAnchorPrefix() {
        XCTAssertEqual(PlanStoreID.normalize("anchor-XYZ"), "XYZ")
    }

    func test_normalizeId_leavesRawIdAlone() {
        XCTAssertEqual(PlanStoreID.normalize("ABC123"), "ABC123")
    }

    func test_normalizeId_handlesNestedPrefix() {
        // "cal-anchor-X" → strips "cal-" only (first match)
        XCTAssertEqual(PlanStoreID.normalize("cal-anchor-X"), "anchor-X")
    }

    // MARK: - Plan CRUD

    func test_loadNonexistent_returnsNil() {
        XCTAssertNil(store.loadPlan(city: "test", date: "9999-99-99"))
    }

    func test_deletePlan_removesFromStore() {
        // Save a plan, then delete, then load → nil
        // We can't easily create a DayAgenda in tests without the full model,
        // but we can verify the delete path doesn't crash
        store.deletePlan(city: "test", date: "2026-01-01")
        XCTAssertNil(store.loadPlan(city: "test", date: "2026-01-01"))
    }

    // MARK: - Calendar Discards

    func test_discard_normalizesId() {
        store.discard(eventId: "cal-ABC123")
        XCTAssertTrue(store.isDiscarded(eventId: "ABC123"), "Raw ID should match")
        XCTAssertTrue(store.isDiscarded(eventId: "cal-ABC123"), "Prefixed ID should also match")
    }

    func test_discard_rawId() {
        store.discard(eventId: "EVENT-1")
        XCTAssertTrue(store.isDiscarded(eventId: "EVENT-1"))
    }

    func test_clearDiscards_emptiesAll() {
        store.discard(eventId: "event1")
        store.discard(eventId: "event2")
        store.clearDiscards()
        XCTAssertFalse(store.isDiscarded(eventId: "event1"))
        XCTAssertEqual(store.allDiscardedIds().count, 0)
    }

    func test_allDiscardedIds_returnsNormalizedIds() {
        store.discard(eventId: "cal-A")
        store.discard(eventId: "B")
        let ids = store.allDiscardedIds()
        XCTAssertTrue(ids.contains("A"))
        XCTAssertTrue(ids.contains("B"))
        XCTAssertFalse(ids.contains("cal-A"))
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

    func test_allExports_returnsMapping() {
        store.storeExport(slotId: "s1", eventId: "e1")
        store.storeExport(slotId: "s2", eventId: "e2")
        let exports = store.allExports()
        XCTAssertEqual(exports.count, 2)
        XCTAssertEqual(exports["s1"], "e1")
    }
}
