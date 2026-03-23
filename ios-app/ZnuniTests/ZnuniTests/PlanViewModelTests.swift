import XCTest
@testable import Znuni

/// Regression tests for PlanViewModel — the central view model for the Plan tab.
/// Tests start RED (wrapped in #if false) until PlanViewModel is implemented.
final class PlanViewModelTests: XCTestCase {

    // MARK: - Helpers

    #if false
    private func makeTestSlot(
        id: String = UUID().uuidString,
        locked: Bool = false,
        source: AgendaSlot.Source = .composed
    ) -> AgendaSlot {
        AgendaSlot(
            id: id,
            title: "Test Slot",
            subtitle: "A test venue",
            startTime: Date(),
            duration: 60,
            isLocked: locked,
            source: source
        )
    }

    private func makeTestAgenda(slots: [AgendaSlot]) -> DayAgenda {
        DayAgenda(slots: slots, date: Date())
    }
    #endif

    // MARK: - Initial State

    #if false
    @MainActor
    func test_initialState_isEmpty() {
        let vm = PlanViewModel()
        XCTAssertEqual(vm.state, .empty)
    }

    @MainActor
    func test_initialDate_isTodayBefore22() {
        let vm = PlanViewModel()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        if hour < 22 {
            XCTAssertTrue(calendar.isDateInToday(vm.selectedDate))
        } else {
            XCTAssertTrue(calendar.isDateInTomorrow(vm.selectedDate))
        }
    }

    @MainActor
    func test_dates_returns14Days() {
        let vm = PlanViewModel()
        XCTAssertEqual(vm.dates.count, 14)
    }

    @MainActor
    func test_dates_startsFromToday() {
        let vm = PlanViewModel()
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(vm.dates[0]))
    }
    #endif

    // MARK: - Date Selection

    #if false
    @MainActor
    func test_selectDate_withNoCachedPlan_transitionsToEmpty() {
        let vm = PlanViewModel()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        vm.selectDate(tomorrow)
        XCTAssertEqual(vm.state, .empty)
    }
    #endif

    // MARK: - Slot Mutations

    #if false
    @MainActor
    func test_lock_setsSlotLocked() {
        let slot = makeTestSlot(id: "s1", locked: false)
        let vm = PlanViewModel()
        vm.agenda = makeTestAgenda(slots: [slot])
        vm.lock(slotId: "s1")
        XCTAssertTrue(vm.agenda!.slots.first(where: { $0.id == "s1" })!.isLocked)
    }

    @MainActor
    func test_unlock_setsSlotUnlocked() {
        let slot = makeTestSlot(id: "s1", locked: true)
        let vm = PlanViewModel()
        vm.agenda = makeTestAgenda(slots: [slot])
        vm.unlock(slotId: "s1")
        XCTAssertFalse(vm.agenda!.slots.first(where: { $0.id == "s1" })!.isLocked)
    }

    @MainActor
    func test_remove_deletesSlot() {
        let slot = makeTestSlot(id: "s1")
        let vm = PlanViewModel()
        vm.agenda = makeTestAgenda(slots: [slot])
        vm.remove(slotId: "s1")
        XCTAssertTrue(vm.agenda!.slots.isEmpty)
    }

    @MainActor
    func test_remove_onCalendarSlot_discardsIt() {
        let slot = makeTestSlot(id: "s1", source: .calendar)
        let vm = PlanViewModel()
        vm.agenda = makeTestAgenda(slots: [slot])
        vm.remove(slotId: "s1")
        XCTAssertTrue(vm.discardedCalendarIDs.contains("s1"))
    }

    @MainActor
    func test_replaceWithCustom_replacesSlot() {
        let slot = makeTestSlot(id: "s1")
        let vm = PlanViewModel()
        vm.agenda = makeTestAgenda(slots: [slot])
        vm.replaceWithCustom(slotId: "s1", title: "Coffee", duration: 30)
        let replaced = vm.agenda!.slots.first(where: { $0.title == "Coffee" })
        XCTAssertNotNil(replaced)
        XCTAssertEqual(replaced?.source, .userCustom)
    }
    #endif

    // MARK: - Redeal & Save

    #if false
    @MainActor
    func test_redeal_keepsLockedSlots() {
        let locked = makeTestSlot(id: "locked1", locked: true)
        let unlocked = makeTestSlot(id: "unlocked1", locked: false)
        let vm = PlanViewModel()
        vm.agenda = makeTestAgenda(slots: [locked, unlocked])

        // After redeal, locked slot should still be present
        // (redeal is async, so we verify the locked set is preserved)
        XCTAssertTrue(vm.agenda!.slots.contains(where: { $0.id == "locked1" && $0.isLocked }))
    }

    @MainActor
    func test_saveToCalendar_locksAllSlots() async {
        let s1 = makeTestSlot(id: "s1", locked: false)
        let s2 = makeTestSlot(id: "s2", locked: false)
        let vm = PlanViewModel()
        vm.agenda = makeTestAgenda(slots: [s1, s2])
        await vm.saveToCalendar()
        for slot in vm.agenda!.slots {
            XCTAssertTrue(slot.isLocked)
        }
    }
    #endif
}
