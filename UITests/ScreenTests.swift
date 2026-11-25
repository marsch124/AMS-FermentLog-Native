import XCTest

/// Lean screen tests: one short test per main screen (2–3 identifiers), and one flow on the sample "Cabbage jar".
/// Everything is found by accessibility identifier, never by its words.
final class ScreenTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(part: String? = nil) -> XCUIApplication {
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"] + ["-part:\(part ?? "jars")"]
        app.launch()
        return app
    }
    private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    private func withPrefix(_ app: XCUIApplication, _ p: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", p))
    }
    private func see(_ app: XCUIApplication, _ ids: String..., file: StaticString = #filePath, line: UInt = #line) {
        for id in ids { XCTAssertTrue(el(app, id).waitForExistence(timeout: 10), "missing \(id)", file: file, line: line) }
    }
    /// Scrolls the page up until the element can be tapped.
    private func reveal(_ app: XCUIApplication, _ e: XCUIElement) {
        var n = 0
        while !e.isHittable && n < 8 { app.swipeUp(); n += 1 }
        XCTAssertTrue(e.isHittable, "\(e.identifier) not reachable")
    }
    /// Opens the sample Cabbage jar from the jars list.
    private func openCabbage() -> XCUIApplication {
        let app = launch()
        let row = el(app, "jar-row-b_sample_cabbage")
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        see(app, "jar-status")
        return app
    }

    func testJarsList() {
        let app = launch()
        see(app, "jars-stats", "jars-start", "jar-row-b_sample_cabbage")
    }
    func testJarPage() {
        let app = openCabbage()
        see(app, "jar-edit", "jar-burped", "jar-plan-progress")
    }
    func testJarForm() {
        let app = openCabbage()
        el(app, "jar-edit").tap()
        see(app, "jar-name", "cancel", "save")
    }
    func testRecipes() {
        let app = launch(part: "recipes")
        see(app, "recipe-row-r_sample_sauerkraut", "recipes-new")
        el(app, "recipe-row-r_sample_sauerkraut").tap()
        see(app, "recipe-edit", "recipe-start-jar")
    }
    func testBakes() {
        let app = launch(part: "bakes")
        see(app, "bake-row-k_sample_1", "bakes-log", "bakes-insights")
        el(app, "bake-row-k_sample_1").tap()
        see(app, "bake-edit", "bake-duplicate")
    }
    func testInsights() {
        let app = launch(part: "insights")
        see(app, "insights-switch", "insights-total", "insights-success")
    }
    func testSearch() {
        let app = launch(part: "search")
        see(app, "search-field")
        let f = el(app, "search-field"); f.tap(); f.typeText("cab")
        XCTAssertTrue(withPrefix(app, "jar-row-").firstMatch.waitForExistence(timeout: 8) || withPrefix(app, "search-").count > 1)
    }
    func testSettings() {
        let app = launch(part: "settings")
        see(app, "settings-screen")
        let g = el(app, "settings-guide"); reveal(app, g)
        see(app, "settings-whats-new", "settings-version")
    }

    /// Burped → one new line; tick a plan step → progress changes; two typed lines → two more lines.
    func testCabbageJarFlow() {
        let app = openCabbage()
        let lines = { self.withPrefix(app, "jar-timeline-line-").count }
        let burp = el(app, "jar-burped"); reveal(app, burp)
        let progress = el(app, "jar-plan-progress").label
        let before = lines()
        burp.tap()
        XCTAssertTrue(waitFor { lines() == before + 1 }, "burp line missing")

        let steps = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'jar-plan-' AND NOT identifier == 'jar-plan-progress'"))
        XCTAssertGreaterThanOrEqual(steps.count, 2)
        let step = steps.element(boundBy: 1); reveal(app, step); step.tap()
        XCTAssertTrue(waitFor { self.el(app, "jar-plan-progress").label != progress }, "progress did not change")

        let afterTick = lines()   // ticking a step writes a line too
        let text = el(app, "jar-timeline-text"); reveal(app, text); text.tap()
        text.typeText("Pressed it down\nAdded a little brine")
        let add = el(app, "jar-timeline-add"); reveal(app, add); add.tap()
        XCTAssertTrue(waitFor { lines() == afterTick + 2 }, "two lines not added (have \(lines()), was \(afterTick))")
    }

    private func waitFor(_ timeout: TimeInterval = 6, _ cond: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end { if cond() { return true }; Thread.sleep(forTimeInterval: 0.3) }
        return cond()
    }
}
