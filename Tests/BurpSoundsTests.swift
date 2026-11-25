import XCTest
import AVFoundation
@testable import AMSFermentLog

/// 6.5: the ten burps, the random pick and what is kept on the device.
final class BurpSoundsTests: XCTestCase {
    func testDefaultAllOn() {
        XCTAssertEqual(BurpSounds.on(off: nil).count, 10)
        XCTAssertEqual(BurpSounds.on(off: "").count, 10)
        let some = BurpSounds.on(off: "3,7")
        XCTAssertEqual(some.count, 8)
        XCTAssertFalse(some.contains { $0.number == 3 || $0.number == 7 })
        XCTAssertEqual(BurpSounds.stored(off: [7, 3]), "3,7")
    }

    func testPickStaysInTheMix() {
        let mix = BurpSounds.on(off: "1,2,4,5,6,8,9,10")          // only 3 and 7 on
        for roll in 0..<50 {
            let p = BurpSounds.pick(on: mix, last: 3, roll: roll)
            XCTAssertEqual(p?.number, 7, "never the same one twice in a row")
        }
        for roll in 0..<50 {
            XCTAssertTrue([3, 7].contains(BurpSounds.pick(on: mix, last: nil, roll: roll)!.number))
        }
        let one = BurpSounds.on(off: "1,2,3,4,5,6,7,8,10")       // only 9 on
        XCTAssertEqual(BurpSounds.pick(on: one, last: 9, roll: 5)?.number, 9, "the only one may repeat")
        XCTAssertNil(BurpSounds.pick(on: [], last: nil, roll: 1), "all off = quiet")
    }

    func testFilesShip() {
        for s in BurpSounds.all {
            let url = Bundle.main.url(forResource: (s.file as NSString).deletingPathExtension, withExtension: "caf")
            XCTAssertNotNil(url, s.file)
            // A real sound the system can play, a quarter of a second to 1.8 seconds (a notification sound must stay under 30).
            let player = url.flatMap { try? AVAudioPlayer(contentsOf: $0) }
            XCTAssertNotNil(player, s.file)
            XCTAssertTrue((0.2...1.8).contains(player?.duration ?? 0), "\(s.file): \(player?.duration ?? 0) s")
        }
    }
}
