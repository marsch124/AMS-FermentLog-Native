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
        XCTAssertEqual(Human.minutes(from: "1–3 weeks"), 20160)
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

/// The Timeline as a rail: one heading per day, a shared time written once; and the line to the next taste test.
final class JarLookTests: XCTestCase {
    private func e(_ id: String, _ date: String, _ time: String, _ kind: TimelineEntry.Kind = .did) -> TimelineEntry {
        TimelineEntry(kind: kind, id: id, date: date, time: time, text: id, isBurp: false)
    }

    func testTimelineDays() {
        let days = Logic.timelineDays([
            e("a", "2026-11-24", "18:00"),
            e("b", "2026-11-25", "14:45"), e("c", "2026-11-25", "14:45"), e("d", "2026-11-25", "20:00"), e("f", "2026-11-25", ""),
            e("g", "2026-11-28", "09:10", .taste),
        ], start: "2026-11-25")
        XCTAssertEqual(days.map(\.date), ["2026-11-24", "2026-11-25", "2026-11-28"])
        XCTAssertEqual(days.map(\.day), [nil, 1, 4])   // the start day is Day 1
        XCTAssertEqual(days[1].lines.map(\.showTime), [true, false, true, false])
        XCTAssertEqual(days[2].lines.map(\.showTime), [true])
        XCTAssertTrue(Logic.timelineDays([], start: "2026-11-25").isEmpty)
    }

    func testStartDayIsDayOne() {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        var b = Logic.newBatch(); b.startDate = "2026-11-25"
        XCTAssertEqual(Logic.dayNumber(b, now: f.date(from: "2026-11-25")!), 1)
        XCTAssertEqual(Logic.dayNumber(b, now: f.date(from: "2026-11-27")!), 3)
        XCTAssertEqual(Logic.fermentDays(b, now: f.date(from: "2026-11-27")!), 2)   // whole days gone by: unchanged
        b.movedToFridgeDate = "2026-12-02"
        XCTAssertEqual(Logic.dayNumber(b, now: f.date(from: "2026-12-20")!), 8)     // stops on the day it went into the fridge
        XCTAssertEqual(Logic.dayNumber(of: "2026-11-25", start: "2026-11-25"), 1)
        XCTAssertNil(Logic.dayNumber(of: "2026-11-24", start: "2026-11-25"))
        XCTAssertNil(Logic.dayNumber(Batch()))
    }

    func testTasteProgress() {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        var b = Logic.newBatch()
        b.startDate = "2026-11-25"; b.remindEveryDays = 3
        XCTAssertEqual(Logic.tasteProgress(b, now: f.date(from: "2026-11-25")!), 0)
        XCTAssertEqual(Logic.tasteProgress(b, now: f.date(from: "2026-11-26")!) ?? -1, 1.0 / 3, accuracy: 0.001)
        XCTAssertEqual(Logic.tasteProgress(b, now: f.date(from: "2026-12-05")!), 1)
        b.remindEveryDays = 0
        XCTAssertNil(Logic.tasteProgress(b, now: f.date(from: "2026-11-26")!))
    }
}


/// The Jars list's tiles: tap one and only that state stays (6.3).
final class JarsFilterTests: XCTestCase {
    func testShowingOneState() {
        var fresh = Logic.newBatch(); fresh.startDate = "2026-11-20"
        var cold = Logic.newBatch(); cold.startDate = "2026-11-01"; cold.movedToFridgeDate = "2026-11-10"
        var over = Logic.newBatch(); over.startDate = "2026-10-01"; var o = Outcome(); o.recorded = true; over.outcome = o
        let all = [fresh, cold, over]
        XCTAssertEqual(Logic.jars(all, showing: nil).count, 3)
        XCTAssertEqual(Logic.jars(all, showing: .fermenting).map(\.id), [fresh.id])
        XCTAssertEqual(Logic.jars(all, showing: .fridge).map(\.id), [cold.id])
        XCTAssertEqual(Logic.jars(all, showing: .done).map(\.id), [over.id])
        XCTAssertTrue(Logic.jars([fresh], showing: .done).isEmpty)
    }
}
