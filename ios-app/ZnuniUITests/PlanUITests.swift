import XCTest

/// UI regression tests for the Plan tab.
/// These tests compile now (they only use XCUITest APIs) but will FAIL
/// until the Plan tab UI is built.
final class PlanUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Tab Bar

    @MainActor
    func test_todayTab_exists() {
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5), "Today tab should exist")
    }

    @MainActor
    func test_newsTab_exists() {
        let newsTab = app.tabBars.buttons["News"]
        XCTAssertTrue(newsTab.waitForExistence(timeout: 5), "News tab should exist")
    }

    @MainActor
    func test_fourTabs_exist() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        let tabButtons = tabBar.buttons
        XCTAssertEqual(tabButtons.count, 4, "Should have exactly 4 tabs")
    }

    // MARK: - Plan View Content

    @MainActor
    func test_todayTab_showsPlanMyDay() {
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let planButton = app.buttons["Plan my day"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 5),
                      "Plan my day button should appear on Today tab")
    }

    @MainActor
    func test_dateStrip_isVisible() {
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        // Today's date number should be visible in the date strip
        let today = Calendar.current.component(.day, from: Date())
        let dateLabel = app.staticTexts["\(today)"]
        XCTAssertTrue(dateLabel.waitForExistence(timeout: 5),
                      "Today's date number should be visible in the date strip")
    }

    @MainActor
    func test_planMyDay_showsCards() {
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let planButton = app.buttons["Plan my day"]
        guard planButton.waitForExistence(timeout: 5) else {
            XCTFail("Plan my day button not found")
            return
        }
        planButton.tap()

        // After tapping, either cards or a loading indicator should appear
        let cardsOrLoading = app.otherElements["agendaTimeline"]
            .waitForExistence(timeout: 10)
            || app.activityIndicators.firstMatch.waitForExistence(timeout: 10)

        XCTAssertTrue(cardsOrLoading,
                      "Cards or loading indicator should appear after tapping Plan my day")
    }

    @MainActor
    func test_dealtState_showsSaveAndRedeal() {
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let planButton = app.buttons["Plan my day"]
        guard planButton.waitForExistence(timeout: 5) else {
            XCTFail("Plan my day button not found")
            return
        }
        planButton.tap()

        // Wait for the plan to load
        let saveButton = app.buttons["Save to Calendar"]
        let redealButton = app.buttons["Redeal"]

        let saveExists = saveButton.waitForExistence(timeout: 15)
        let redealExists = redealButton.waitForExistence(timeout: 5)

        XCTAssertTrue(saveExists, "Save to Calendar button should appear after deal")
        XCTAssertTrue(redealExists, "Redeal button should appear after deal")
    }
}
