import XCTest

final class HackersPubUITests: XCTestCase {
    private let uiTimeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGuestCanIndividuallyDeleteASeededRecentSearch() {
        let app = makeGuestApp(seedingRecentSearch: true)
        app.launch()

        openSearch(in: app)
        let recentSearch = app.buttons["search.recent.UI test recent search"]
        XCTAssertTrue(recentSearch.waitForExistence(timeout: uiTimeout))
        recentSearch.swipeLeft()
        let deleteButton = app.buttons["search.recent.delete.UI test recent search"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: uiTimeout))
        deleteButton.tap()

        XCTAssertTrue(element("search.initial", in: app).waitForExistence(timeout: uiTimeout))
    }

    @MainActor
    func testGuestKeyboardSearchSubmitRecordsAndClearsRecentSearches() {
        let app = makeGuestApp()
        app.launch()

        openSearch(in: app)
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: uiTimeout))
        searchField.tap()
        searchField.typeText("ui test")
        app.keyboards.buttons["Search"].tap()

        let resolvedResult = element("search.result.resolved.ui-test-post", in: app)
        XCTAssertTrue(resolvedResult.waitForExistence(timeout: uiTimeout))

        searchField.tap()
        let clearButton = searchField.buttons.firstMatch
        XCTAssertTrue(clearButton.waitForExistence(timeout: uiTimeout))
        clearButton.tap()

        XCTAssertTrue(app.buttons["search.recent.ui test"].waitForExistence(timeout: uiTimeout))
        app.buttons["search.recent.clear"].tap()
        XCTAssertTrue(element("search.initial", in: app).waitForExistence(timeout: uiTimeout))
    }

    @MainActor
    func testGuestLaunchSeedsRouterSearchBeforeSearchViewAppears() {
        let app = makeGuestApp(seedingRouterSearch: true)
        app.launch()

        let resolvedResult = element("search.result.resolved.ui-test-post", in: app)
        XCTAssertTrue(resolvedResult.waitForExistence(timeout: uiTimeout))
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func makeGuestApp(
        seedingRecentSearch: Bool = false,
        seedingRouterSearch: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-com.hackerspub.ui-test.force-guest",
            "-com.hackerspub.ui-test.reset-search-state",
            "-com.hackerspub.ui-test.search-stub",
            "-com.hackerspub.ui-test.no-live-root-network"
        ]
        if seedingRecentSearch {
            app.launchArguments.append("-com.hackerspub.ui-test.seed-recent-search")
        }
        if seedingRouterSearch {
            app.launchArguments.append("-com.hackerspub.ui-test.seed-router-search")
        }
        return app
    }

    @MainActor
    private func openSearch(in app: XCUIApplication) {
        let searchTab = app.buttons["tab.search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: uiTimeout))
        searchTab.tap()
        XCTAssertTrue(app.otherElements["search.screen"].waitForExistence(timeout: uiTimeout))
    }
}
