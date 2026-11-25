import XCTest
@testable import AMSFermentLog

/// The launch arguments for pictures: they name pages, and they do nothing outside a "-uiTesting" run.
final class PictureArgsTests: XCTestCase {
    func testPageNames() {
        XCTAssertEqual(Route(argument: "jarEdit:b_1"), .jarEdit("b_1"))
        XCTAssertEqual(Route(argument: "recipe:r:with:colons"), .recipe("r:with:colons"))
        XCTAssertEqual(Route(argument: "guide"), .guide)
        XCTAssertNil(Route(argument: "nonsense"))
    }
    func testSilentWithoutUITesting() {
        // The data tests run without "-uiTesting": nothing may be read from the arguments then.
        XCTAssertFalse(PictureArgs.on)
        XCTAssertNil(PictureArgs.value("open"))
        XCTAssertFalse(PictureArgs.has("tall"))
    }
}
