import XCTest
@testable import AMSFermentLog

final class AlarmPlanTests: XCTestCase {
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 10, minute: 0))!

    private func jar(lid: String = "Plain lid", start: String = "2026-11-23", alarm: Bool? = nil) -> Batch {
        var b = Batch(); b.id = "b1"; b.name = "Cabbage jar"; b.vegetable = "Cabbage"; b.lidType = lid; b.startDate = start; b.burpAlarm = alarm
        b.remindEveryDays = 0
        return b
    }
    private func data(_ b: Batch) -> AppData { var d = AppData(); d.batches = [b]; return d }
    private func plan(_ b: Batch, burp: Bool = true, taste: Bool = true, limit: Int = 60) -> [AlarmPlan.Planned] {
        AlarmPlan.plan(data: data(b), burpHere: burp, tasteHere: taste, now: now, limit: limit)
    }

    func testPlainLidGivesFourteenSlotsInSevenDays() {
        let p = plan(jar())
        XCTAssertEqual(p.count, 14)
        XCTAssertEqual(p.first?.title, "Burp: Cabbage jar")
        XCTAssertEqual(p.first?.category, "BURP")
        XCTAssertEqual(p.first?.id, "burp.b1.202611252000")
        XCTAssertEqual(p.first?.body, "Evening burp \u{00B7} day 3. Tap Burped when it is done.")
        XCTAssertTrue(p[1].body.hasPrefix("Morning burp"))
        XCTAssertEqual(p.map(\.fireAt), p.map(\.fireAt).sorted())
    }

    func testAirlockNoneUnlessSwitchedOn() {
        XCTAssertTrue(plan(jar(lid: "Airlock")).isEmpty)
        XCTAssertEqual(plan(jar(lid: "Airlock", alarm: true)).count, 14)
    }

    func testFridgeJarNone() {
        var b = jar(); b.movedToFridgeDate = "2026-11-24"
        XCTAssertTrue(plan(b).isEmpty)
    }

    func testBurpedNote() {
        let n = AlarmPlan.burpedNote(batchID: "b1", jarTitle: "Cabbage jar", at: at(2026, 11, 25, 8, 12), sound: BurpSounds.sound(3)!)
        XCTAssertEqual(n.id, "burped.b1")
        XCTAssertEqual(n.title, "Burped: Cabbage jar")
        XCTAssertEqual(n.body, "Written in the Timeline at 08:12. Burp: Chuckle.")
        XCTAssertEqual(n.category, "BURPED")
        XCTAssertEqual(n.sound, "burp-03.caf")
        XCTAssertFalse(n.id.hasPrefix(AlarmPlan.burpPrefix), "the re-plan must never take it for a reminder")
    }

    func testBurpHereFalseNone() {
        XCTAssertTrue(plan(jar(), burp: false).isEmpty)
    }

    func testBurpLoggedAnHourBeforeSlotRemovesIt() {
        var b = jar(); b.steps = [Step(date: "2026-11-25", time: "19:00", text: "Burped the jar", kind: "burp")]
        let p = plan(b)
        XCTAssertEqual(p.count, 13)
        XCTAssertFalse(p.contains { $0.id == "burp.b1.202611252000" })
    }

    func testLimitCutsTheFarthest() {
        let all = plan(jar())
        let cut = plan(jar(), limit: 3)
        XCTAssertEqual(cut, Array(all.prefix(3)))
    }

    func testTasteReminderOnDueDayAtMorningTime() {
        var b = jar(lid: "Airlock"); b.remindEveryDays = 3     // start 23rd -> due 26th
        let p = plan(b)
        XCTAssertEqual(p.count, 1)
        XCTAssertEqual(p[0].id, "taste.b1.2026-11-26")
        XCTAssertEqual(p[0].fireAt, at(2026, 11, 26, 8, 0))
        XCTAssertEqual(p[0].title, "Taste test: Cabbage jar")
        XCTAssertEqual(p[0].body, "Day 4 \u{2014} time to taste and write a line.")
        XCTAssertTrue(plan(b, taste: false).isEmpty)
    }

    func testTasteDueTodayAfterMorningTimeIsNotPlanned() {
        var b = jar(lid: "Airlock", start: "2026-11-22"); b.remindEveryDays = 3    // due today, 08:00 already past
        XCTAssertTrue(plan(b).isEmpty)
    }
}
