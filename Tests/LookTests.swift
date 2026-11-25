import XCTest
@testable import AMSFermentLog

/// The plain-words rules of the 6.1 look: days, step times, ingredient amounts.
final class LookTests: XCTestCase {
    private func date(_ s: String) -> Date {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.date(from: s)!
    }

    func testDayInPlainWords() {
        let now = date("2026-11-25")
        XCTAssertEqual(Human.day("2026-11-25", now: now), "Wed 25 Nov")
        XCTAssertEqual(Human.day("2025-12-31", now: now), "Wed 31 Dec 2025")
        XCTAssertEqual(Human.day("soon", now: now), "soon")
        XCTAssertEqual(Human.day("", now: now), "")
    }

    func testFromNow() {
        let now = date("2026-11-25")
        XCTAssertEqual(Human.fromNow("2026-11-25", now: now), "today")
        XCTAssertEqual(Human.fromNow("2026-11-26", now: now), "tomorrow")
        XCTAssertEqual(Human.fromNow("2026-11-28", now: now), "in 3 days")
        XCTAssertEqual(Human.fromNow("2026-11-24", now: now), "yesterday")
        XCTAssertEqual(Human.fromNow("2026-11-20", now: now), "5 days ago")
        XCTAssertNil(Human.fromNow("x", now: now))
        XCTAssertEqual(Human.days(from: "2026-11-25", to: "2026-11-28"), 3)
    }

    func testMinutesFromStepWords() {
        XCTAssertEqual(Human.minutes(from: "4–6 h (or overnight)"), 300)
        XCTAssertEqual(Human.minutes(from: "1 h"), 60)
        XCTAssertEqual(Human.minutes(from: "15 min"), 15)
        XCTAssertEqual(Human.minutes(from: "4-6 h at ~22°C"), 300)
        XCTAssertEqual(Human.minutes(from: "12–16 h"), 840)
        XCTAssertEqual(Human.minutes(from: "1 h 30 min"), 90)
        XCTAssertEqual(Human.minutes(from: "2 days"), 2880)
        XCTAssertEqual(Human.minutes(from: "45 minutes"), 45)
        XCTAssertNil(Human.minutes(from: "day 5"))
        XCTAssertNil(Human.minutes(from: "daily"))
        XCTAssertNil(Human.minutes(from: "350 ml water"))
        XCTAssertTrue(Human.isLongWait(120)); XCTAssertFalse(Human.isLongWait(119))
    }

    func testAmountOfAnIngredient() {
        XCTAssertEqual(Human.amount("100 g active sourdough starter")?.amount, "100 g")
        XCTAssertEqual(Human.amount("100 g active sourdough starter")?.rest, "active sourdough starter")
        XCTAssertEqual(Human.amount("2 large onions")?.amount, "2")
        XCTAssertEqual(Human.amount("2 large onions")?.rest, "large onions")
        XCTAssertEqual(Human.amount("1.5 kg cabbage")?.amount, "1.5 kg")
        XCTAssertEqual(Human.amount("1 tbsp caraway seeds")?.amount, "1 tbsp")
        XCTAssertNil(Human.amount("Kitchen scale"))
        XCTAssertNil(Human.amount("Salt to taste"))
    }
}
