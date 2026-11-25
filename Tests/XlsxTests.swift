import XCTest
@testable import AMSFermentLog

final class XlsxTests: XCTestCase {
    func testWorkbookIsAZipWithSheetsAndEscapedText() throws {
        let sheet = Sheet(name: "Ferments", columns: [("Name", 20), ("Salt (g)", 8)],
                          rows: [[.text("Dill & <garlic> \"mix\""), .number(25)], [.text(""), .number(2.5)]])
        let data = Xlsx.workbook([sheet, Sheet(name: "Bakes", columns: [("Name", 10)], rows: [])])
        XCTAssertEqual(Array(data.prefix(2)), Array("PK".utf8))
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("xl/worksheets/sheet1.xml"))
        XCTAssertTrue(text.contains("xl/worksheets/sheet2.xml"))
        XCTAssertTrue(text.contains("Dill &amp; &lt;garlic&gt; &quot;mix&quot;"))
        XCTAssertFalse(text.contains("Dill & <garlic>"))
        XCTAssertTrue(text.contains("<v>25</v>"))
        XCTAssertTrue(text.contains("<v>2.5</v>"))
    }

    func testCRC32OfKnownText() {
        XCTAssertEqual(Xlsx.crc32(Data("123456789".utf8)), 0xCBF43926)
        XCTAssertEqual(Xlsx.columnLetter(0), "A")
        XCTAssertEqual(Xlsx.columnLetter(26), "AA")
    }

    @MainActor func testRealExportBuilds() {
        let data = Xlsx.workbook(Logic.exportSheets(AppData.sample))
        XCTAssertGreaterThan(data.count, 1000)
    }
}
