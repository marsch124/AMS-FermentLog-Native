import XCTest
@testable import AMSFermentLog

final class RibbonTests: XCTestCase {
    func testRibbonWidths() {
        let w = Ribbon.widths(minutes: [300, 15, 840], total: 300, minWidth: 18, gap: 2)
        XCTAssertEqual(w.count, 3)
        XCTAssertEqual(w.reduce(0, +) + 4, 300, accuracy: 0.01)
        XCTAssertEqual(w[1], 18, accuracy: 0.01)
        XCTAssertTrue(w[2] > w[0] && w[0] > w[1])
        let tight = Ribbon.widths(minutes: [1, 2, nil], total: 40, minWidth: 18, gap: 2)
        XCTAssertEqual(tight[0], tight[2], accuracy: 0.01)
    }
}
