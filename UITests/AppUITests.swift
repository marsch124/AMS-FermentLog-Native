import XCTest

/// UI tests: every control is found by its accessibility identifier, never by its words (Martin's rule).
final class AppUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func launch(part: String? = nil, sample: Bool = true, extra: [String] = []) -> XCUIApplication {
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (sample ? ["-sample"] : []) + (part.map { ["-part:\($0)"] } ?? []) + extra
        app.launch()
        return app
    }

    /// Any element with an identifier that starts with a prefix (list items carry their record id).
    func first(_ app: XCUIApplication, prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }
    func count(_ app: XCUIApplication, prefix: String) -> Int {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).count
    }

    /// The app opens on its first area: the Home tab on the iPhone, the Jars row of the sidebar on iPad and Mac.
    func testLaunchShowsTheFirstArea() {
        let app = launch()
        let tab = app.descendants(matching: .any)["tab-home"].firstMatch
        let side = app.descendants(matching: .any)["sidebar-jars"].firstMatch
        // 30 s: the first launch on GitHub's shared Mac can take long (6.6's run timed out at 10 s while the other 74 passed).
        XCTAssertTrue(tab.waitForExistence(timeout: 30) || side.waitForExistence(timeout: 2))
    }
}
