import XCTest

final class HackersPubUITestsLaunchTests: XCTestCase {
    private let uiTimeout: TimeInterval = 5

    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGuestLaunchShowsSearchAndSignInTabs() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-com.hackerspub.ui-test.force-guest",
            "-com.hackerspub.ui-test.reset-search-state",
            "-com.hackerspub.ui-test.no-live-root-network"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["tab.search"].waitForExistence(timeout: uiTimeout))
        XCTAssertTrue(app.buttons["tab.sign-in"].waitForExistence(timeout: uiTimeout))
    }
}
