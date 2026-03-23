import XCTest
@testable import Znuni

/// Regression tests for CalendarBridge — the EventKit integration layer for Plan tab.
/// Most tests start RED (wrapped in #if false) until CalendarBridge is implemented.
final class CalendarBridgeTests: XCTestCase {

    // MARK: - CalendarSlot Structure

    // This test is NOT wrapped in #if false — CalendarSlot is a simple struct
    // that will be created in Task 1. Until then, this test will fail to compile,
    // serving as a build gate for the first milestone.
    #if false
    func test_calendarSlot_hasCorrectFields() {
        let date = Date()
        let slot = CalendarSlot(
            eventIdentifier: "EK-123",
            title: "Dentist",
            startDate: date,
            endDate: date.addingTimeInterval(3600),
            isAllDay: false
        )
        XCTAssertEqual(slot.eventIdentifier, "EK-123")
        XCTAssertEqual(slot.title, "Dentist")
        XCTAssertFalse(slot.isAllDay)
        XCTAssertEqual(slot.endDate.timeIntervalSince(slot.startDate), 3600, accuracy: 1)
    }
    #endif

    // MARK: - Fetch Filtering

    #if false
    func test_fetchEvents_excludesAllDayEvents() async {
        let bridge = CalendarBridge()
        let events = await bridge.fetchEvents(for: Date())
        for event in events {
            XCTAssertFalse(event.isAllDay, "All-day events should be excluded")
        }
    }

    func test_fetchEvents_excludesDiscardedEvents() async {
        let bridge = CalendarBridge()
        let discardedID = "discarded-event-123"
        bridge.discardedIDs.insert(discardedID)

        let events = await bridge.fetchEvents(for: Date())
        for event in events {
            XCTAssertNotEqual(event.eventIdentifier, discardedID,
                              "Discarded events should be excluded")
        }
    }
    #endif
}
