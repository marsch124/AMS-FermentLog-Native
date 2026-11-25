import XCTest

/// Walks every screen and saves numbered pictures. Runs only when SHOT_DIR is set (TEST_RUNNER_SHOT_DIR on the xcodebuild line);
/// otherwise every test skips, so Apple's run never does it. SHOT_DARK=1 → dark. SHOT_LANDSCAPE=1 → iPad on its side. Sample data only.
final class ShotTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var out: String { ProcessInfo.processInfo.environment["SHOT_DIR"] ?? "" }
    private var dark: Bool { ProcessInfo.processInfo.environment["SHOT_DARK"] == "1" }
    private var landscape: Bool { ProcessInfo.processInfo.environment["SHOT_LANDSCAPE"] == "1" }

    private func start(_ part: String? = nil) throws -> XCUIApplication {
        guard !out.isEmpty else { throw XCTSkip("SHOT_DIR not set") }
        try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        #if os(iOS)
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        #endif
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample", dark ? "-dark" : "-light"] + ["-part:\(part ?? "jars")"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)
        return app
    }
    private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    private func prefix(_ app: XCUIApplication, _ p: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", p)).firstMatch
    }
    private func shot(_ n: Int, _ name: String) {
        Thread.sleep(forTimeInterval: 0.9)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: out).appendingPathComponent(String(format: "%02d-%@.png", n, name)))
    }
    private func tap(_ app: XCUIApplication, _ id: String, scroll: Bool = true) {
        let e = el(app, id)
        XCTAssertTrue(e.waitForExistence(timeout: 8), "missing \(id)")
        if scroll { reveal(app, e) }
        e.tap()
    }
    private func reveal(_ app: XCUIApplication, _ e: XCUIElement) {
        var n = 0
        while !e.isHittable && n < 10 { app.swipeUp(); n += 1 }
        n = 0
        while !e.isHittable && n < 14 { app.swipeDown(); n += 1 }   // it may sit above where the page is scrolled to
    }
    /// Scrolls a page by a screenful at a time (works on the one scroll view in front).
    private func scroll(_ app: XCUIApplication, _ times: Int) {
        for _ in 0..<times { app.swipeUp(velocity: .slow); Thread.sleep(forTimeInterval: 0.3) }
    }
    private func openCabbage(_ app: XCUIApplication) {
        tap(app, "jar-row-b_sample_cabbage", scroll: false)
        XCTAssertTrue(el(app, "jar-status").waitForExistence(timeout: 8))
    }
    private func cancel(_ app: XCUIApplication) { if el(app, "cancel").exists { el(app, "cancel").tap() } }

    func test1_JarsAndJarPage() throws {
        let app = try start()
        XCTAssertTrue(el(app, "jar-row-b_sample_cabbage").waitForExistence(timeout: 10))
        shot(1, "jars-list")
        openCabbage(app)
        shot(2, "jar-top")
        scroll(app, 1); shot(3, "jar-burp-todo")
        let add = el(app, "jar-timeline-add"); reveal(app, add)
        shot(4, "jar-timeline-add")
        // line editor sheet
        let line = prefix(app, "jar-timeline-line-")
        if !line.isHittable { app.swipeDown(velocity: .slow) }
        if line.exists { line.tap(); if el(app, "jar-line-text").waitForExistence(timeout: 5) { shot(6, "jar-line-editor"); cancel(app) } }
        Thread.sleep(forTimeInterval: 1)
        for _ in 0..<4 { app.swipeUp() }
        shot(5, "jar-outcome-actions")
        let rec = el(app, "jar-outcome-record"); reveal(app, rec)
        rec.tap()
        if el(app, "outcome-success").waitForExistence(timeout: 6) { shot(7, "outcome-sheet"); cancel(app) }
    }

    func test2_JarForm() throws {
        let app = try start()
        openCabbage(app)
        tap(app, "jar-edit", scroll: false)
        XCTAssertTrue(el(app, "jar-name").waitForExistence(timeout: 8))
        shot(8, "jar-form-top")
        for _ in 0..<8 { app.swipeUp() }
        shot(9, "jar-form-bottom")
    }

    func test3_FinishedJar() throws {
        let app = try start()
        tap(app, "jar-row-b_sample_beets")
        XCTAssertTrue(el(app, "jar-status").waitForExistence(timeout: 8))
        scroll(app, 2)
        shot(10, "jar-finished")
    }

    func test4_Bakes() throws {
        let app = try start("bakes")
        XCTAssertTrue(el(app, "bake-row-k_sample_1").waitForExistence(timeout: 10))
        shot(11, "bakes-list")
        tap(app, "bake-row-k_sample_1")
        XCTAssertTrue(el(app, "bake-edit").waitForExistence(timeout: 8))
        shot(12, "bake-page")
        tap(app, "bake-edit", scroll: false)
        XCTAssertTrue(el(app, "bake-name").waitForExistence(timeout: 8))
        shot(13, "bake-form")
    }

    func test5_BakeInsights() throws {
        let app = try start("bakes")
        tap(app, "bakes-insights")
        Thread.sleep(forTimeInterval: 1.5)
        shot(14, "bake-insights")
        scroll(app, 2); shot(14 + 100, "bake-insights-lower")   // extra picture, numbered 114
    }

    func test6_Recipes() throws {
        let app = try start("recipes")
        XCTAssertTrue(el(app, "recipe-row-r_sample_sauerkraut").waitForExistence(timeout: 10))
        shot(15, "recipes-list")
        tap(app, "recipe-row-r_sample_sauerkraut")
        XCTAssertTrue(el(app, "recipe-edit").waitForExistence(timeout: 8))
        shot(16, "recipe-top")
        scroll(app, 2); shot(17, "recipe-method-actions")
        for _ in 0..<4 { app.swipeDown() }
        tap(app, "recipe-edit", scroll: false)
        XCTAssertTrue(el(app, "recipe-title").waitForExistence(timeout: 8))
        let steps = el(app, "recipe-add-step"); reveal(app, steps)
        shot(18, "recipe-form-steps")
    }

    func test7_Insights() throws {
        let app = try start("insights")
        XCTAssertTrue(el(app, "insights-total").waitForExistence(timeout: 10))
        shot(19, "insights-top")
        scroll(app, 2); shot(20, "insights-charts")
    }

    func test8_Search() throws {
        let app = try start("search")
        let f = el(app, "search-field")
        XCTAssertTrue(f.waitForExistence(timeout: 10))
        f.tap(); f.typeText("cab")
        Thread.sleep(forTimeInterval: 1)
        shot(21, "search-cab")
    }

    func test9_Settings() throws {
        let app = try start("settings")
        XCTAssertTrue(el(app, "settings-screen").waitForExistence(timeout: 10))
        shot(22, "settings-top")
        scroll(app, 2); shot(23, "settings-middle")
        let ver = el(app, "settings-version"); reveal(app, ver)
        shot(24, "settings-bottom")
        tap(app, "settings-manage-lists")
        Thread.sleep(forTimeInterval: 1); shot(25, "your-lists")
        app.navigationBars.buttons.firstMatch.tap()
        tap(app, "settings-safety-copies")
        Thread.sleep(forTimeInterval: 1); shot(26, "safety-copies")
        app.navigationBars.buttons.firstMatch.tap()
        tap(app, "settings-guide")
        Thread.sleep(forTimeInterval: 1); shot(27, "how-it-works")
        app.navigationBars.buttons.firstMatch.tap()
        tap(app, "settings-whats-new")
        Thread.sleep(forTimeInterval: 1); shot(28, "whats-new")
    }

    func test91_NewTab() throws {
        let app = try start("new")
        Thread.sleep(forTimeInterval: 1)
        if el(app, "new-menu").exists { el(app, "new-menu").tap(); Thread.sleep(forTimeInterval: 0.8) }
        shot(29, "new")
    }
}
