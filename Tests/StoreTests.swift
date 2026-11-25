import XCTest
@testable import AMSFermentLog

@MainActor
final class StoreTests: XCTestCase {
    private func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AMSFermentLogTests-\(UUID().uuidString)")
    }
    private func jar(_ name: String) -> Batch { var b = Batch(); b.name = name; b.vegetable = "Cabbage"; return b }

    /// Save, then a fresh store on the same folder reads it back.
    func testSaveAndReloadRoundTrip() {
        let root = tempRoot()
        let a = Store(root: root)
        let b = jar("Cabbage jar")
        a.save(b)
        a.saveNow()
        let again = Store(root: root)
        XCTAssertEqual(again.data.liveBatches.map(\.name), ["Cabbage jar"])
        XCTAssertEqual(again.data.format, AppData.currentFormat)
    }

    /// Two devices saved different jars from the same starting point: nothing is lost.
    func testDivergedCopiesMergeWithoutLosingARecord() {
        let root = tempRoot()
        let phone = Store(root: root)
        let mac = Store(root: root)          // both started empty
        phone.save(jar("From the phone")); phone.saveNow()
        mac.save(jar("From the Mac")); mac.saveNow()   // merges with what the phone wrote, never replaces it
        let reader = Store(root: root)
        XCTAssertEqual(Set(reader.data.liveBatches.map(\.name)), ["From the phone", "From the Mac"])
    }

    /// A jar removed on one device stays removed when an older copy of it is merged in.
    func testTombstonedJarStaysRemovedAfterMerge() {
        let root = tempRoot()
        let a = Store(root: root)
        let b = jar("Old jar")
        a.save(b)
        a.update { $0.batches[0].modifiedAt = Date(timeIntervalSinceNow: -60) }   // the date is stored in whole seconds
        a.saveNow()
        let stale = Store(root: root)                      // another device that still shows the live jar
        XCTAssertEqual(stale.data.liveBatches.count, 1)
        a.remove(batch: b.id)
        a.saveNow()
        stale.saveNow()                                     // the stale device writes: the removal must survive
        let reader = Store(root: root)
        XCTAssertTrue(reader.data.liveBatches.isEmpty)
        XCTAssertEqual(reader.data.batches.count, 1)        // the tombstone is kept
    }
}
