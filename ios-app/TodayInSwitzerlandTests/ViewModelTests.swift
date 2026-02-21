import XCTest
@testable import TodayInSwitzerland

/// Tests for ViewModel logic (filtering, sorting, computed properties).
/// Note: These tests don't hit the network — they test pure logic on the ViewModels.
final class ViewModelTests: XCTestCase {

    // MARK: - News ViewModel

    @MainActor
    func testNewsCategoryKeys() {
        let vm = NewsViewModel()
        // Simulate loaded data
        vm.newsData = PreviewData.newsResponse

        let keys = vm.categoryKeys
        XCTAssertTrue(keys.contains("topStories"))
        XCTAssertTrue(keys.contains("politics"))
        // Empty categories should be excluded
        XCTAssertFalse(keys.contains("culture"))
    }

    @MainActor
    func testNewsCurrentItems() {
        let vm = NewsViewModel()
        vm.newsData = PreviewData.newsResponse
        vm.selectedCategory = "topStories"

        XCTAssertEqual(vm.currentItems.count, 1)
        XCTAssertEqual(vm.currentItems[0].headline, "Swiss National Bank holds rates steady")
    }

    @MainActor
    func testNewsItemCount() {
        let vm = NewsViewModel()
        vm.newsData = PreviewData.newsResponse

        XCTAssertEqual(vm.itemCount(for: "topStories"), 1)
        XCTAssertEqual(vm.itemCount(for: "disruptions"), 1)
        XCTAssertEqual(vm.itemCount(for: "culture"), 0)
    }

    // MARK: - Activities ViewModel

    @MainActor
    func testActivitiesFilterAll() {
        let vm = ActivitiesViewModel()
        vm.activitiesData = ActivitiesResponse(
            activities: [PreviewData.activity, PreviewData.stayHomeActivity],
            cityEvents: [],
            weather: PreviewData.weather,
            city: CityInfo(id: "zurich", name: "Zürich")
        )
        vm.filter = .all

        let filtered = vm.filteredActivities(savedIDs: [])
        // .all should exclude stayHome
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].id, "zoo-zurich")
    }

    @MainActor
    func testActivitiesFilterStayHome() {
        let vm = ActivitiesViewModel()
        vm.activitiesData = ActivitiesResponse(
            activities: [PreviewData.activity, PreviewData.stayHomeActivity],
            cityEvents: [],
            weather: PreviewData.weather,
            city: CityInfo(id: "zurich", name: "Zürich")
        )
        vm.filter = .stayHome

        let filtered = vm.filteredActivities(savedIDs: [])
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].id, "sensory-bin")
    }

    @MainActor
    func testActivitiesFilterSaved() {
        let vm = ActivitiesViewModel()
        vm.activitiesData = ActivitiesResponse(
            activities: [PreviewData.activity, PreviewData.stayHomeActivity],
            cityEvents: [],
            weather: PreviewData.weather,
            city: CityInfo(id: "zurich", name: "Zürich")
        )
        vm.filter = .saved

        let filtered = vm.filteredActivities(savedIDs: ["zoo-zurich"])
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].id, "zoo-zurich")
    }

    @MainActor
    func testActivitiesFilterIndoor() {
        let vm = ActivitiesViewModel()
        vm.activitiesData = ActivitiesResponse(
            activities: [PreviewData.activity, PreviewData.stayHomeActivity],
            cityEvents: [],
            weather: PreviewData.weather,
            city: CityInfo(id: "zurich", name: "Zürich")
        )
        vm.filter = .indoor

        let filtered = vm.filteredActivities(savedIDs: [])
        // Zoo is outdoor, stayHome is excluded from indoor filter
        XCTAssertEqual(filtered.count, 0)
    }

    @MainActor
    func testActivitiesSurpriseMe() {
        let vm = ActivitiesViewModel()
        vm.activitiesData = ActivitiesResponse(
            activities: [PreviewData.activity],
            cityEvents: [],
            weather: PreviewData.weather,
            city: CityInfo(id: "zurich", name: "Zürich")
        )

        let surprise = vm.surpriseMe(weather: PreviewData.weather, savedIDs: [])
        XCTAssertNotNil(surprise)
    }

    // MARK: - Events ViewModel

    @MainActor
    func testEventsMonthNavigation() {
        let vm = EventsViewModel()
        let originalMonth = vm.currentMonth
        let originalYear = vm.currentYear

        vm.nextMonth()
        if originalMonth == 12 {
            XCTAssertEqual(vm.currentMonth, 1)
            XCTAssertEqual(vm.currentYear, originalYear + 1)
        } else {
            XCTAssertEqual(vm.currentMonth, originalMonth + 1)
        }

        vm.previousMonth()
        XCTAssertEqual(vm.currentMonth, originalMonth)
        XCTAssertEqual(vm.currentYear, originalYear)
    }

    @MainActor
    func testEventsDateSelection() {
        let vm = EventsViewModel()
        let testDate = Date()

        vm.selectDate(testDate)
        XCTAssertNotNil(vm.selectedDate)

        // Selecting same date again deselects
        vm.selectDate(testDate)
        XCTAssertNil(vm.selectedDate)
    }

    // MARK: - Deals ViewModel

    @MainActor
    func testDealsFilterAll() {
        let vm = DealsViewModel()
        vm.filter = .all

        let deals = vm.filteredDeals(city: .zurich)
        XCTAssertGreaterThan(deals.count, 0)
    }

    @MainActor
    func testDealsFilterFree() {
        let vm = DealsViewModel()
        vm.filter = .free

        let deals = vm.filteredDeals(city: .zurich)
        for deal in deals {
            XCTAssertEqual(deal.type, .free)
        }
    }

    @MainActor
    func testDealsCityFiltering() {
        let vm = DealsViewModel()
        vm.filter = .all

        let zurichDeals = vm.filteredDeals(city: .zurich)
        let genevaDeals = vm.filteredDeals(city: .geneva)

        // Zurich should have more deals (city-specific + all)
        XCTAssertGreaterThanOrEqual(zurichDeals.count, genevaDeals.count)
    }

    // MARK: - AppState

    func testAppStateSavedActivities() {
        let state = AppState()
        let testID = "test-activity-\(UUID().uuidString)"

        state.toggleSavedActivity(testID)
        XCTAssertTrue(state.savedActivityIDs.contains(testID))

        state.toggleSavedActivity(testID)
        XCTAssertFalse(state.savedActivityIDs.contains(testID))
    }

    func testAppStateLunchRating() {
        let state = AppState()
        let testID = "test-lunch-\(UUID().uuidString)"

        state.setLunchRating(testID, rating: 4)
        XCTAssertEqual(state.lunchRatings[testID], 4)
    }

    // MARK: - Localization

    func testNewsItemLocalization() {
        let item = PreviewData.newsItem

        XCTAssertEqual(item.localizedHeadline(language: .en), "Swiss National Bank holds rates steady")
        XCTAssertEqual(item.localizedHeadline(language: .de), "Schweizerische Nationalbank hält Zinsen stabil")
    }

    func testCityLocalization() {
        XCTAssertEqual(City.geneva.localizedName(language: .en), "Geneva")
        XCTAssertEqual(City.geneva.localizedName(language: .de), "Genf")
    }

    func testHistoryLocalization() {
        let fact = PreviewData.newsResponse.history
        XCTAssertTrue(fact.localizedEvent(language: .en).contains("Expo 58"))
        XCTAssertTrue(fact.localizedEvent(language: .de).contains("Expo 58"))
    }
}
