import XCTest
@testable import SwissPortal

final class GapAnalysisEngineTests: XCTestCase {

    // Helpers
    private func date(_ timeStr: String, offset daysFromToday: Int = 0) -> Date {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date()).addingTimeInterval(Double(daysFromToday) * 86400)
        let parts = timeStr.split(separator: ":").map { Int($0)! }
        return cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: base)!
    }

    private func anchor(
        _ title: String,
        category: AnchorCategory,
        start: String,
        durationMinutes: Int
    ) -> AnchorEvent {
        AnchorEvent(
            id: UUID(),
            title: title,
            category: category,
            startTime: date(start),
            durationMinutes: durationMinutes,
            neighbourhood: nil,
            kreis: nil,
            sourceEventId: nil,
            createdDate: Date()
        )
    }

    // ─────────────────────────────────────────────
    // Test 1: Empty day at 09:00 → full 4 gaps
    // ─────────────────────────────────────────────
    func test_emptyDay_09h00_returnsFourGaps() {
        let now = date("09:00")
        let gaps = GapAnalysisEngine.analyse(anchors: [], now: now, date: now)
        let fillable = gaps.filter { $0.isFillable }
        let types = fillable.map { $0.suggestedType! }

        XCTAssertEqual(fillable.count, 4)
        XCTAssertTrue(types.contains(.morningActivity))
        XCTAssertTrue(types.contains(.lunch))
        XCTAssertTrue(types.contains(.afternoonActivity))
        XCTAssertTrue(types.contains(.dinner))
    }

    // ─────────────────────────────────────────────
    // Test 2: Empty day at 13:43 → afternoon + dinner
    // Morning and lunch windows are elapsed
    // ─────────────────────────────────────────────
    func test_emptyDay_13h43_returnsAfternoonAndDinner() {
        let now = date("13:43")
        let gaps = GapAnalysisEngine.analyse(anchors: [], now: now, date: now)
        let fillable = gaps.filter { $0.isFillable }
        let types = Set(fillable.map { $0.suggestedType! })

        XCTAssertFalse(types.contains(.morningActivity), "Morning should be elapsed")
        XCTAssertFalse(types.contains(.lunch), "Lunch window should be elapsed or too short")
        XCTAssertTrue(types.contains(.afternoonActivity))
        XCTAssertTrue(types.contains(.dinner))
    }

    // ─────────────────────────────────────────────
    // Test 3: Brunch anchor (food) + Party anchor (social) at 13:43
    // This is the exact bug scenario from the screenshots.
    // Only dinner should be suggested.
    // ─────────────────────────────────────────────
    func test_brunchAndParty_13h43_returnsDinnerOnly() {
        let now = date("13:43")
        let anchors = [
            anchor("Brunch at Khouris", category: .food,   start: "11:15", durationMinutes: 90),
            anchor("Noah's birthday",   category: .social, start: "14:00", durationMinutes: 180)
        ]
        let gaps = GapAnalysisEngine.analyse(anchors: anchors, now: now, date: now)
        let fillable = gaps.filter { $0.isFillable }
        let types = Set(fillable.map { $0.suggestedType! })

        XCTAssertEqual(fillable.count, 1, "Only one fillable gap — dinner after the party")
        XCTAssertTrue(types.contains(.dinner))
        XCTAssertFalse(types.contains(.lunch),             "Brunch anchor suppresses lunch")
        XCTAssertFalse(types.contains(.morningActivity),   "Morning is elapsed")
        XCTAssertFalse(types.contains(.afternoonActivity), "Party anchor suppresses afternoon")
    }

    // ─────────────────────────────────────────────
    // Test 4: Dinner anchor at 19:00, now = 09:00
    // Should get morning + lunch + afternoon, no dinner
    // ─────────────────────────────────────────────
    func test_dinnerAnchor_09h00_suppressesDinner() {
        let now = date("09:00")
        let anchors = [
            anchor("Dinner out", category: .food, start: "19:00", durationMinutes: 120)
        ]
        let gaps = GapAnalysisEngine.analyse(anchors: anchors, now: now, date: now)
        let fillable = gaps.filter { $0.isFillable }
        let types = Set(fillable.map { $0.suggestedType! })

        XCTAssertTrue(types.contains(.morningActivity))
        XCTAssertTrue(types.contains(.lunch))
        XCTAssertTrue(types.contains(.afternoonActivity))
        XCTAssertFalse(types.contains(.dinner), "Dinner anchor should suppress dinner suggestion")
    }

    // ─────────────────────────────────────────────
    // Test 5: Anchors cover the full day → no fillable gaps
    // ─────────────────────────────────────────────
    func test_fullDayAnchors_returnsNoFillableGaps() {
        let now = date("09:00")
        let anchors = [
            anchor("Morning class",  category: .activity, start: "08:00", durationMinutes: 180),
            anchor("Lunch with family", category: .food,  start: "11:00", durationMinutes: 120),
            anchor("Afternoon event", category: .social,  start: "13:00", durationMinutes: 240),
            anchor("Dinner",         category: .food,     start: "17:00", durationMinutes: 240)
        ]
        let gaps = GapAnalysisEngine.analyse(anchors: anchors, now: now, date: now)
        let fillable = gaps.filter { $0.isFillable }

        XCTAssertEqual(fillable.count, 0, "Full day anchors should leave no fillable gaps")
    }

    // ─────────────────────────────────────────────
    // Test 6: Now = 20:30, no anchors → too late, no gaps
    // ─────────────────────────────────────────────
    func test_emptyDay_20h30_returnsNoFillableGaps() {
        let now = date("20:30")
        let gaps = GapAnalysisEngine.analyse(anchors: [], now: now, date: now)
        let fillable = gaps.filter { $0.isFillable }

        XCTAssertEqual(fillable.count, 0, "Only 30min left in day — below 45min threshold")
    }

    // ─────────────────────────────────────────────
    // Bonus: Single anchor in the middle — gaps before and after
    // ─────────────────────────────────────────────
    func test_singleMidDayAnchor_returnsMorningAndDinner() {
        let now = date("09:00")
        let anchors = [
            anchor("Lunch with Grandma", category: .food, start: "12:00", durationMinutes: 120)
        ]
        let gaps = GapAnalysisEngine.analyse(anchors: anchors, now: now, date: now)
        let fillable = gaps.filter { $0.isFillable }
        let types = Set(fillable.map { $0.suggestedType! })

        XCTAssertTrue(types.contains(.morningActivity), "Gap before lunch anchor should be fillable")
        XCTAssertFalse(types.contains(.lunch), "Lunch anchor suppresses lunch suggestion")
        XCTAssertTrue(types.contains(.dinner) || types.contains(.afternoonActivity),
                      "Gap after lunch anchor should produce afternoon or dinner")
    }

    // ─────────────────────────────────────────────
    // Bonus: Anchor end time calculation is correct
    // ─────────────────────────────────────────────
    func test_anchorEndTime_calculatedCorrectly() {
        let a = anchor("Test", category: .activity, start: "10:00", durationMinutes: 90)
        let expectedEnd = date("11:30")
        XCTAssertEqual(
            Calendar.current.dateComponents([.hour, .minute], from: a.endTime),
            Calendar.current.dateComponents([.hour, .minute], from: expectedEnd)
        )
    }
}
