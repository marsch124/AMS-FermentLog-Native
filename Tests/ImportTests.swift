import XCTest
@testable import AMSFermentLog

@MainActor
final class ImportTests: XCTestCase {
    private func tempStore() -> Store {
        Store(root: FileManager.default.temporaryDirectory.appendingPathComponent("AMSFermentLogImport-\(UUID().uuidString)"))
    }
    private let webBackup = """
    {"app":"fermentlog","version":3,"batches":[
      {"id":"w1","vegetable":"Carrot","form":"Sticks","startDate":"2026-10-01","additions":["Dill","Juniper"],"loggedBy":"Eva",
       "photos":["data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ=="]},
      {"id":"w2","vegetable":"Kohlrabi","startDate":"2026-10-05"}],
     "recipes":[{"id":"r1","title":"Sauerkraut"}],"bakeLessons":[{"id":"l1","text":"More salt"}]}
    """

    func testImportingTheSameWebFileTwiceDoesNotDuplicate() throws {
        let store = tempStore()
        let result = try WebImport.read(Data(webBackup.utf8))
        let first = ImportApply.bringInWebBackup(result, into: store)
        XCTAssertTrue(first.hasPrefix("Brought in 2 jars"))
        XCTAssertEqual(store.data.liveBatches.count, 2)
        let photoFiles = try FileManager.default.contentsOfDirectory(atPath: store.photosURL.path).count
        XCTAssertEqual(photoFiles, 1)
        ImportApply.bringInWebBackup(try WebImport.read(Data(webBackup.utf8)), into: store)
        XCTAssertEqual(store.data.liveBatches.count, 2)
        XCTAssertEqual(store.data.liveRecipes.count, 1)
        XCTAssertEqual(store.data.liveLessons.count, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: store.photosURL.path).count, 1)
        XCTAssertEqual(store.data.settings.customVegetables, ["Kohlrabi"])
    }

    func testWrongFilesAreRefusedInPlainWords() {
        XCTAssertThrowsError(try WebImport.read(Data("{\"hello\":1}".utf8))) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "This file is not a FermentLog backup.")
        }
        XCTAssertThrowsError(try ImportApply.parseBackup(Data("[1,2]".utf8)))
        XCTAssertThrowsError(try ImportApply.parseBackup(Data(webBackup.utf8))) {
            XCTAssertEqual($0 as? ImportApply.BackupProblem, .fromTheWebApp)
        }
    }

    func testOwnBackupRoundTripsAndRestoreMerges() throws {
        let store = tempStore()
        var b = Batch(); b.name = "Jar one"; store.save(b)
        let raw = try JSONEncoder.app.encode(store.data)
        let parsed = try ImportApply.parseBackup(raw)
        XCTAssertEqual(parsed.liveBatches.count, 1)
        let other = tempStore()
        ImportApply.restoreBackup(parsed, into: other)
        ImportApply.restoreBackup(parsed, into: other)
        XCTAssertEqual(other.data.liveBatches.map(\.name), ["Jar one"])
    }

    func testCountsLine() {
        XCTAssertEqual(ImportApply.countsLine(jars: 7, bakes: 2, recipes: 3, lessons: 4, presets: 1, photos: 12),
                       "7 jars, 2 bakes, 3 recipes, 4 lessons, 1 template, 12 pictures")
        XCTAssertEqual(ImportApply.countsLine(jars: 1, bakes: 0, recipes: 0, lessons: 0, presets: 0, photos: 0), "1 jar")
    }

    func testRenameAndRemoveEverywhere() {
        var d = AppData()
        var b = Batch(); b.vegetable = "Kohlrabi"; b.additions = ["Juniper", "Dill"]; d.batches = [b]
        var p = Preset(); p.vegetable = "Kohlrabi"; p.additions = ["Juniper"]; d.presets = [p]
        d.settings.customVegetables = ["Kohlrabi"]; d.settings.customSpices = ["Juniper"]
        XCTAssertEqual(SettingsListEdit.usage(.vegetable, "Kohlrabi", in: d), "used in 1 jar and 1 template")
        SettingsListEdit.rename(.vegetable, from: "Kohlrabi", to: "Turnip", in: &d)
        XCTAssertEqual(d.batches[0].vegetable, "Turnip"); XCTAssertEqual(d.presets[0].vegetable, "Turnip")
        XCTAssertEqual(d.settings.customVegetables, ["Turnip"])
        XCTAssertFalse(SettingsListEdit.remove(.vegetable, "Turnip", in: &d))
        XCTAssertTrue(SettingsListEdit.remove(.spice, "Juniper", in: &d))
        XCTAssertEqual(d.batches[0].additions, ["Dill"]); XCTAssertTrue(d.presets[0].additions.isEmpty)
    }
}
