import XCTest
import Foundation
@testable import AMSFermentLog

final class LogicTests: XCTestCase {
    private func at(_ day: String, _ time: String = "12:00") -> Date { Logic.date(fromDay: day, time: time)! }

    private func finished(_ name: String, salt: Double, water: Double, temp: Double, veg: String, lid: String,
                          overall: Int, success: Bool, problems: [String] = [], start: String, fridge: String) -> Batch {
        var b = Batch()
        b.name = name; b.vegetable = veg; b.saltGrams = salt; b.waterMl = water; b.roomTempC = temp; b.lidType = lid
        b.startDate = start; b.movedToFridgeDate = fridge
        var o = Outcome(); o.recorded = true; o.success = success; o.overall = overall; o.problems = problems
        b.outcome = o
        return b
    }

    // MARK: ported from tests/model.test.mjs

    func testBrine() {
        XCTAssertEqual(Logic.computeBrinePercent(salt: 25, water: 975), 2.5)
        XCTAssertEqual(Logic.computeBrinePercent(salt: 20, water: 980), 2)
        XCTAssertNil(Logic.computeBrinePercent(salt: nil, water: 1000))
        XCTAssertNil(Logic.computeBrinePercent(salt: 0, water: 0))
        XCTAssertNil(Logic.computeBrinePercent(salt: -5, water: 1000))
        XCTAssertTrue(Logic.isBrineInRange(2.5))
        XCTAssertFalse(Logic.isBrineInRange(1.9))
        XCTAssertFalse(Logic.isBrineInRange(3.1))
        XCTAssertFalse(Logic.isBrineInRange(nil))
    }

    func testDaysAndStatus() {
        let now = at("2026-02-01")
        XCTAssertEqual(Logic.daysBetween(start: "2026-01-01", end: "2026-01-08", now: now), 7)
        XCTAssertEqual(Logic.daysBetween(start: "2026-01-10", end: "2026-01-01", now: now), 0)
        XCTAssertNil(Logic.daysBetween(start: "", end: "2026-01-08", now: now))
        XCTAssertEqual(Logic.daysBetween(start: "2026-01-01", end: nil, now: now), 31)
        var b = Batch(); b.startDate = "2026-01-01"; b.movedToFridgeDate = "2026-01-11"
        XCTAssertEqual(Logic.fermentDays(b, now: now), 10)
        XCTAssertEqual(Logic.batchStatus(b), .fridge)
        var o = Outcome(); o.recordedAt = at("2026-01-06", "10:00")
        b.movedToFridgeDate = ""; b.outcome = o
        XCTAssertEqual(Logic.fermentDays(b, now: now), 5)
        XCTAssertEqual(Logic.batchStatus(b), .fermenting)
        o.recorded = true; b.outcome = o
        XCTAssertEqual(Logic.batchStatus(b), .done)
        XCTAssertNil(Logic.fermentDays(Batch(), now: now))
        XCTAssertEqual(Logic.statusLabel(.fridge), "In fridge")
    }

    func testRatings() {
        var b = Batch(); var o = Outcome(); o.overall = 4; b.outcome = o
        XCTAssertEqual(Logic.overallRating(b), 4)
        o = Outcome(); o.taste = 4; o.sourness = 2; o.crunch = 3; b.outcome = o
        XCTAssertEqual(Logic.overallRating(b), 3)
        b.outcome = Outcome(); XCTAssertNil(Logic.overallRating(b))
        b.outcome = nil; XCTAssertNil(Logic.overallRating(b))
        XCTAssertEqual(Logic.ratingStars(3), "\u{2605}\u{2605}\u{2605}\u{2606}\u{2606}")
        XCTAssertEqual(Logic.ratingStars(nil), "\u{2014}")
    }

    func testNewBatchDefaults() {
        let b = Logic.newBatch(now: at("2026-07-21", "10:00"))
        XCTAssertEqual(b.vegetable, "Carrot"); XCTAssertEqual(b.form, "Sticks")
        XCTAssertEqual(b.startDate, "2026-07-21"); XCTAssertEqual(b.remindEveryDays, Logic.DEFAULT_REMIND_DAYS)
        XCTAssertNotEqual(Logic.newBatch().id, Logic.newBatch().id)
        XCTAssertNil(b.outcome)
    }

    func testReminders() {
        var b = Batch(); b.startDate = "2026-07-01"; b.remindEveryDays = 3
        XCTAssertEqual(Logic.nextCheckDue(b), "2026-07-04")
        b.checkIns = [CheckIn(date: "2026-07-05", tasteNote: "x")]
        XCTAssertEqual(Logic.nextCheckDue(b), "2026-07-08")
        b.checkIns = []
        XCTAssertTrue(Logic.isCheckDue(b, today: at("2026-07-04", "09:00")))
        XCTAssertFalse(Logic.isCheckDue(b, today: at("2026-07-03", "09:00")))
        var other = Batch(); other.startDate = "2026-07-20"; other.remindEveryDays = 3
        XCTAssertEqual(Logic.dueBatches([b, other], today: at("2026-07-05")).map(\.id), [b.id])
        b.remindEveryDays = 0; XCTAssertNil(Logic.nextCheckDue(b))
        b.remindEveryDays = 3; b.movedToFridgeDate = "2026-07-05"; XCTAssertNil(Logic.nextCheckDue(b))
        b.movedToFridgeDate = ""; var o = Outcome(); o.recorded = true; b.outcome = o; XCTAssertNil(Logic.nextCheckDue(b))
    }

    func testStats() {
        let empty = Logic.summarizeStats([])
        XCTAssertEqual(empty.total, 0); XCTAssertNil(empty.successRate); XCTAssertNil(empty.bestBatch)
        XCTAssertTrue(empty.ratingVsBrine.isEmpty); XCTAssertTrue(empty.vegetables.isEmpty)

        let a = finished("A", salt: 25, water: 975, temp: 20, veg: "Carrot sticks", lid: "Airlock", overall: 5, success: true, start: "2026-06-01", fridge: "2026-06-11")
        let bb = finished("B", salt: 20, water: 980, temp: 24, veg: "Carrot sticks", lid: "Plain lid", overall: 2, success: false, problems: ["Mould"], start: "2026-06-15", fridge: "2026-06-22")
        let c = finished("C", salt: 30, water: 970, temp: 18, veg: "Cabbage", lid: "Airlock", overall: 4, success: true, start: "2026-07-01", fridge: "2026-07-14")
        var d = Batch(); d.name = "D"; d.vegetable = "Carrot sticks"; d.startDate = "2026-07-20"
        let s = Logic.summarizeStats([a, bb, c, d], now: at("2026-08-01"))
        XCTAssertEqual(s.total, 4); XCTAssertEqual(s.active, 1); XCTAssertEqual(s.finished, 3)
        XCTAssertEqual(s.successRate!, 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(s.bestBatch?.name, "A"); XCTAssertEqual(s.bestRating, 5)
        XCTAssertEqual(s.ratingVsBrine.count, 3); XCTAssertEqual(s.ratingVsDays.count, 3)
        XCTAssertEqual(s.ratingOverTime.map(\.x), [1, 2, 3])
        XCTAssertEqual(s.ratingOverTime.map(\.name), ["A", "B", "C"])
        XCTAssertEqual(s.vegetables, ["Cabbage", "Carrot sticks"])
        XCTAssertEqual(s.problems.first { $0.label == "Mould" }?.value, 1)
        XCTAssertEqual(s.byLid.first?.label, "Airlock")   // (5+4)/2 = 4.5 beats 2

        let only = Logic.summarizeStats([a, c], vegetable: "Cabbage")
        XCTAssertEqual(only.total, 1); XCTAssertEqual(only.bestBatch?.name, "C")
        XCTAssertEqual(only.vegetables, ["Cabbage", "Carrot sticks"])
    }

    func testRecommendation() {
        let a = finished("A", salt: 25, water: 975, temp: 20, veg: "Carrot sticks", lid: "Airlock", overall: 5, success: true, start: "2026-06-01", fridge: "2026-06-11")
        let b = finished("B", salt: 24, water: 976, temp: 21, veg: "Carrot sticks", lid: "Airlock", overall: 4, success: true, start: "2026-06-15", fridge: "2026-06-23")
        let c = finished("C", salt: 20, water: 980, temp: 25, veg: "Cabbage", lid: "Plain lid", overall: 2, success: false, start: "2026-07-01", fridge: "2026-07-05")
        let rec = Logic.recommendation([a, b, c])!
        XCTAssertEqual(rec.count, 2); XCTAssertEqual(rec.lid, "Airlock"); XCTAssertEqual(rec.vegetable, "Carrot sticks")
        XCTAssertTrue(rec.brine! > 2 && rec.brine! < 3)
        XCTAssertEqual(rec.days, 9)   // median of 10 and 8
        XCTAssertNil(Logic.recommendation([c]))
    }

    func testCSV() {
        var p = Batch(); p.name = "Plain"; p.vegetable = "Carrot sticks"; p.startDate = "2026-07-01"; p.saltGrams = 25; p.waterMl = 975
        var q = Batch(); q.name = "Has, comma \"and\" quote"; q.vegetable = "Cabbage"; q.startDate = "2026-07-02"; q.notes = "line1\nline2"
        q.steps = Logic.stepsFromText("Chopped", date: "2026-07-02", time: "10:30")
        let csv = Logic.toCSV([p, q])
        XCTAssertTrue(csv.hasPrefix("Name,Vegetable,Form,Start date"))
        XCTAssertTrue(csv.contains("\"Has, comma \"\"and\"\" quote\""))
        XCTAssertTrue(csv.contains("\"line1\nline2\""))
        XCTAssertTrue(csv.contains("2.5"))
        XCTAssertTrue(csv.components(separatedBy: "\n")[0].hasSuffix(",What I did"))
        XCTAssertTrue(csv.contains("2026-07-02 10:30 \u{2014} Chopped"))
    }

    func testFullCSVAndSheets() {
        var data = AppData()
        var b = Batch(); b.name = "Garlic carrots"; b.saltGrams = 25; b.waterMl = 975; data.batches = [b]
        var k = Bake(); k.name = "Country loaf"; k.category = "Sourdough"; k.ratings.crust = 4; k.ratings.crumb = 3; k.ratings.flavour = 5; k.problems = ["dense"]; k.notes = "nice"
        data.bakes = [k]
        var r = Recipe(); r.title = "Everyday sourdough"; r.ingredients = ["flour", "water"]; r.steps = [RecipeStep(title: "Bulk", detail: "warm", time: "4h")]
        data.recipes = [r]
        var l = Lesson(); l.text = "Longer cold proof = tangier"; l.createdAt = Logic.date(fromDay: "2026-07-21", time: "10:00")!
        data.lessons = [l]
        let csv = Logic.toFullCSV(data)
        for label in ["# Ferments (batches)", "# Bakes", "# Recipes", "# Lessons learned & improvements", "Garlic carrots", "1. Bulk (4h): warm"] { XCTAssertTrue(csv.contains(label), label) }
        XCTAssertTrue(csv.contains("Country loaf,Sourdough,,,4,3,5,4,dense,nice"))
        XCTAssertTrue(csv.contains("Longer cold proof = tangier,,,,2026-07-21 10:00"))
        XCTAssertTrue(Logic.toFullCSV(AppData()).contains("(none yet)"))

        let sheets = Logic.exportSheets(data)
        XCTAssertEqual(sheets.map(\.name), ["Ferments", "Bakes", "Recipes", "Lessons"])
        XCTAssertEqual(sheets[0].columns.count, 23); XCTAssertEqual(sheets[0].columns[2].header, "Form")
        XCTAssertEqual(sheets[0].rows[0][0], .text("Garlic carrots"))
        XCTAssertEqual(sheets[0].rows[0][5], .number(2.5))          
    }

    func testPresetsAndDuplicates() {
        var src = Logic.newBatch(now: at("2026-07-21", "10:00"))
        src.name = "Spicy carrot #1"; src.saltGrams = 30; src.roomTempC = 19; src.lidType = "Airlock"; src.additions = ["Garlic", "Dill"]
        src.checkIns = [CheckIn(date: "2026-07-03", tasteNote: "good")]; src.steps = [Step(date: "2026-07-01", text: "x")]
        src.plan = [PlanStep(title: "p")]; src.photos = ["a.jpg"]; src.movedToFridgeDate = "2026-07-10"
        var o = Outcome(); o.recorded = true; src.outcome = o
        let preset = Logic.presetFromBatch(src, name: "My carrots")
        XCTAssertEqual(preset.name, "My carrots")
        let b = Logic.batchFromPreset(preset, now: at("2026-08-01", "10:00"))
        XCTAssertEqual(b.saltGrams, 30); XCTAssertEqual(b.roomTempC, 19); XCTAssertEqual(b.lidType, "Airlock")
        XCTAssertEqual(b.additions, ["Garlic", "Dill"]); XCTAssertEqual(b.startDate, "2026-08-01")
        let dup = Logic.duplicateBatch(src, now: at("2026-08-01", "10:00"))
        XCTAssertEqual(dup.name, "Spicy carrot #1 (copy)")
        XCTAssertTrue(dup.checkIns.isEmpty && dup.steps.isEmpty && dup.plan.isEmpty && dup.photos.isEmpty)
        XCTAssertNil(dup.outcome); XCTAssertEqual(dup.movedToFridgeDate, ""); XCTAssertEqual(dup.startDate, "2026-08-01")
        XCTAssertNotEqual(dup.id, src.id)
    }

    func testListsAndCustoms() {
        XCTAssertFalse(Logic.VEGETABLES.contains("Other"))
        var a = Batch(); a.vegetable = "Kohlrabi"; a.additions = ["Garlic", "Turmeric"]
        var b = Batch(); b.vegetable = "Ramson"; b.additions = ["Fennel seed", "Turmeric"]
        var c = Batch(); c.vegetable = "Carrot"; var d = Batch(); d.vegetable = "Kohlrabi"
        XCTAssertEqual(Logic.usedVegetables([a, b, c, d]), ["Kohlrabi", "Ramson"])
        XCTAssertEqual(Logic.usedSpices([a, b, c]), ["Fennel seed", "Turmeric"])
        let m = Logic.mergeVegetables(["Kohlrabi", "Carrot", "Kohlrabi"])
        XCTAssertEqual(m.first, "Carrot"); XCTAssertEqual(m.filter { $0 == "Kohlrabi" }.count, 1); XCTAssertEqual(m.filter { $0 == "Carrot" }.count, 1)
        let sp = Logic.mergeSpices(["Turmeric", "Garlic", "Turmeric"])
        XCTAssertEqual(sp.first, Logic.COMMON_SPICES[0]); XCTAssertEqual(sp.filter { $0 == "Turmeric" }.count, 1)
        XCTAssertEqual(Logic.renamedList(["Garlic", "Dill"], "Garlic", "Roasted garlic"), ["Roasted garlic", "Dill"])
        XCTAssertEqual(Logic.renamedList(["Garlic", "Dill"], "Dill", "Garlic"), ["Garlic"])
        XCTAssertEqual(Logic.renamedList(["A", ""], "A", ""), [])
        XCTAssertEqual(Logic.withoutItem(["Garlic", "Dill", "Garlic"], "Garlic"), ["Dill"])
        XCTAssertTrue(Logic.splitVegForm("Carrot sticks") == (vegetable: "Carrot", form: "Sticks"))
        XCTAssertTrue(Logic.splitVegForm("Red cabbage slices") == (vegetable: "Red cabbage", form: "Slices"))
        XCTAssertTrue(Logic.splitVegForm("Green beans") == (vegetable: "Green beans", form: ""))
        XCTAssertTrue(Logic.splitVegForm("") == (vegetable: "", form: ""))
    }

    func testRecipesAndBakes() {
        let r = Logic.newRecipe(now: at("2026-07-21"))
        XCTAssertEqual(r.category, "Sourdough"); XCTAssertTrue(Logic.RECIPE_CATEGORIES.contains(r.category)); XCTAssertEqual(r.createdAt, r.modifiedAt)
        XCTAssertNotEqual(Logic.newRecipe().id, Logic.newRecipe().id)
        let s = Logic.sampleSourdoughRecipe()
        XCTAssertTrue(s.title.contains("Sourdough")); XCTAssertTrue(s.ingredients.count >= 4 && s.equipment.count >= 3 && s.steps.count >= 5)
        XCTAssertTrue(s.steps.allSatisfy { !$0.title.isEmpty && !$0.time.isEmpty })
        var dup = Logic.duplicateRecipe(s, now: at("2026-08-01"))
        XCTAssertEqual(dup.title, s.title + " (copy)"); XCTAssertNotEqual(dup.id, s.id)
        dup.steps[0].title = "changed"; XCTAssertNotEqual(s.steps[0].title, "changed")

        let k = Logic.newBake(now: at("2026-07-21"))
        XCTAssertEqual(k.category, "Sourdough"); XCTAssertEqual(k.bakeDate, "2026-07-21")
        var src = Logic.newBake(now: at("2026-06-01")); src.name = "Country loaf"; src.ratings.overall = 5
        let bd = Logic.duplicateBake(src, now: at("2026-07-21"))
        XCTAssertEqual(bd.name, "Country loaf (copy)"); XCTAssertEqual(bd.bakeDate, "2026-07-21"); XCTAssertNotEqual(bd.id, src.id)

        var x = Bake(); x.ratings.overall = 5; XCTAssertEqual(Logic.overallBakeRating(x), 5)
        x = Bake(); x.ratings.crust = 4; x.ratings.crumb = 2; x.ratings.flavour = 3; XCTAssertEqual(Logic.overallBakeRating(x), 3)
        XCTAssertNil(Logic.overallBakeRating(Bake()))
    }

    func testSummarizeBakes() {
        XCTAssertEqual(Logic.summarizeBakes([]).total, 0); XCTAssertNil(Logic.summarizeBakes([]).avgOverall)
        func bake(_ n: String, _ cat: String, _ rec: String, _ date: String, overall: Int? = nil, parts: Int? = nil, problems: [String] = []) -> Bake {
            var b = Bake(); b.name = n; b.category = cat; b.recipeTitle = rec; b.bakeDate = date; b.problems = problems
            b.ratings.overall = overall; b.ratings.crust = parts; b.ratings.crumb = parts; b.ratings.flavour = parts
            return b
        }
        let s = Logic.summarizeBakes([bake("A", "Sourdough", "Everyday", "2026-06-01", overall: 5), bake("B", "Sourdough", "Everyday", "2026-06-08", overall: 3, problems: ["Dense crumb"]),
                                      bake("C", "Bread", "", "2026-06-15", parts: 4, problems: ["Dense crumb"]), bake("D", "Sourdough", "", "2026-06-20")])
        XCTAssertEqual(s.total, 4); XCTAssertEqual(s.rated, 3); XCTAssertEqual(s.bestBake?.name, "A"); XCTAssertEqual(s.bestRating, 5)
        XCTAssertEqual(s.byRecipe.first { $0.label == "Everyday" }?.value, 4); XCTAssertEqual(s.byRecipe.first { $0.label == "Everyday" }?.count, 2)
        XCTAssertEqual(s.problems.first { $0.label == "Dense crumb" }?.value, 2)
        XCTAssertEqual(s.ratingOverTime.map(\.name), ["A", "B", "C"])
    }

    func testSearch() {
        var b1 = Batch(); b1.name = "Spicy carrot"; b1.vegetable = "Carrot sticks"; b1.additions = ["Garlic"]; b1.checkIns = [CheckIn(date: "", tasteNote: "very tangy")]
        b1.steps = [Step(date: "", text: "Salted heavily")]; b1.plan = [PlanStep(title: "Rinse the radishes")]
        var b2 = Batch(); b2.name = "Kraut"; b2.vegetable = "Cabbage"
        var k = Bake(); k.name = "Country loaf"; k.category = "Sourdough"; k.problems = ["Dense crumb"]
        var r = Recipe(); r.title = "Everyday Sourdough"; r.category = "Sourdough"; r.ingredients = ["500 g flour"]
        XCTAssertEqual(Logic.searchAll("", batches: [b1], bakes: [k], recipes: [r]).total, 0)
        XCTAssertEqual(Logic.searchAll("carrot", batches: [b1, b2], bakes: [k], recipes: [r]).batches.map(\.id), [b1.id])
        let sour = Logic.searchAll("sourdough", batches: [b1, b2], bakes: [k], recipes: [r])
        XCTAssertEqual(sour.bakes.count, 1); XCTAssertEqual(sour.recipes.count, 1)
        XCTAssertEqual(Logic.searchAll("tangy garlic", batches: [b1, b2]).batches.count, 1)
        XCTAssertEqual(Logic.searchAll("salted", batches: [b1, b2]).batches.count, 1)         // steps are searched
        XCTAssertEqual(Logic.searchAll("radishes", batches: [b1, b2]).batches.count, 1)          // plan titles too
        XCTAssertEqual(Logic.searchAll("carrot zzzz", batches: [b1, b2]).total, 0)
    }

    func testTimeline() {
        let pasted = "1. Saved the outer cabbage leaves\n2. Chopped the cabbage\n3. 2% of the weight salt\n\n10) Burp, every day\n\t\u{2022}\t\t11.\tTry after three or four days\n- 2.5 kg cabbage"
        XCTAssertEqual(Logic.parseStepLines(pasted), ["Saved the outer cabbage leaves", "Chopped the cabbage", "2% of the weight salt", "Burp, every day", "Try after three or four days", "2.5 kg cabbage"])
        XCTAssertEqual(Logic.parseStepLines(""), [])

        var b = Batch(); b.startDate = "2026-11-25"; b.remindEveryDays = 3
        b.steps = Logic.stepsFromText("Chopped\nSalted", date: "2026-11-25", time: "10:30") + [Step(date: "2026-11-26", time: "08:00", text: "Burped")]
        b.checkIns = [CheckIn(date: "2026-11-25", tasteNote: "old note, no time"), CheckIn(date: "2026-11-28", time: "18:15", tasteNote: "Tangy")]
        let tl = Logic.timelineEntries(b)
        XCTAssertEqual(tl.map { "\($0.kind.rawValue):\($0.text)" }, ["did:Chopped", "did:Salted", "taste:old note, no time", "did:Burped", "taste:Tangy"])
        XCTAssertEqual(tl[1].id, b.steps[1].id)
        XCTAssertEqual(Logic.stepsText(b), "2026-11-25 10:30 \u{2014} Chopped\n2026-11-25 10:30 \u{2014} Salted\n2026-11-26 08:00 \u{2014} Burped")
        // the taste reminder counts from the last taste check-in, never from steps
        XCTAssertEqual(Logic.nextCheckDue(b), "2026-12-01")
    }

    // MARK: NEW rules

    func testBurpAlarm() {
        var b = Batch(); b.lidType = "Plain lid"; b.startDate = "2026-11-25"
        XCTAssertTrue(Logic.burpAlarmOn(b))
        b.lidType = "Airlock"; XCTAssertFalse(Logic.burpAlarmOn(b))
        b.burpAlarm = true; XCTAssertTrue(Logic.burpAlarmOn(b))
        b.lidType = "Plain lid"; b.burpAlarm = false; XCTAssertFalse(Logic.burpAlarmOn(b))
        b.burpAlarm = nil; b.movedToFridgeDate = "2026-11-26"; XCTAssertFalse(Logic.burpAlarmOn(b))   // not fermenting any more
        b.movedToFridgeDate = ""

        var s = AppSettings(); s.burpMorning = "08:00"; s.burpEvening = "20:00"
        let now = at("2026-11-25", "09:00")
        let slots = Logic.burpSlots(for: b, settings: s, from: now, days: 2)
        XCTAssertEqual(slots, [at("2026-11-25", "20:00"), at("2026-11-26", "08:00"), at("2026-11-26", "20:00"), at("2026-11-27", "08:00")])
        XCTAssertEqual(Logic.burpSlots(for: b, settings: s, from: now).count, 14)   // evening today + 6 full days + the 8th morning
        // a burp within 3 h before a slot skips it
        Logic.burped(&b, at: at("2026-11-25", "18:30"))
        XCTAssertEqual(Logic.lastBurp(b), at("2026-11-25", "18:30"))
        XCTAssertEqual(Logic.burpsToday(b, now: now), 1)
        XCTAssertEqual(b.steps.last?.text, "Burped the jar"); XCTAssertEqual(b.steps.last?.kind, "burp")
        let after = Logic.burpSlots(for: b, settings: s, from: now, days: 1)
        XCTAssertFalse(after.contains(at("2026-11-25", "20:00")))
        XCTAssertTrue(after.contains(at("2026-11-26", "08:00")))
        b.lidType = "Airlock"; b.burpAlarm = false
        XCTAssertTrue(Logic.burpSlots(for: b, settings: s, from: now).isEmpty)
    }

    func testRecipeFromJarSteps() {
        var b = Batch(); b.name = ""; b.vegetable = "Cabbage"; b.form = "Shredded"; b.saltGrams = 20; b.waterMl = 500.5
        b.additions = ["Dill"]; b.startDate = "2026-11-25"; b.vesselType = "Crock"; b.weightType = "None"; b.lidType = ""
        b.steps = [Step(date: "2026-11-25", time: "10:00", text: "Chopped"), Step(date: "2026-11-26", time: "08:00", text: "Burped the jar", kind: "burp"),
                   Step(date: "2026-11-26", time: "09:00", text: "Burp it again by hand")]
        b.checkIns = [CheckIn(date: "2026-11-27", tasteNote: "Tangy")]
        let r = Logic.recipe(fromStepsOf: b, now: at("2026-11-30"))
        XCTAssertEqual(r.title, "Cabbage"); XCTAssertEqual(r.category, "Vegetable ferment")
        XCTAssertEqual(r.description, "From the jar started 2026-11-25.")
        XCTAssertEqual(r.ingredients, ["Cabbage, shredded", "20 g salt", "500.5 ml water", "Dill"])
        XCTAssertEqual(r.equipment, ["Crock"])
        XCTAssertEqual(r.steps.map(\.title), ["Chopped", "Burp it again by hand"])
    }

    func testRecipeTickList() {
        var r = Recipe(); r.title = "Spicy cabbage"; r.ingredients = ["1 cabbage", "garlic", "Turmeric"]
        r.steps = [RecipeStep(title: "Chop", detail: "fine", time: "5 min"), RecipeStep(title: "", detail: "Salt it", time: ""), RecipeStep()]
        var b = Logic.batch(from: r, now: at("2026-11-25", "10:00"), customSpices: ["Turmeric"])
        XCTAssertEqual(b.recipeID, r.id); XCTAssertEqual(b.recipeTitle, "Spicy cabbage"); XCTAssertEqual(b.name, "Spicy cabbage")
        XCTAssertEqual(b.vegetable, "Cabbage"); XCTAssertEqual(b.additions, ["Garlic", "Turmeric"]); XCTAssertEqual(b.notes, "From recipe: Spicy cabbage")
        XCTAssertEqual(b.plan.map(\.title), ["Chop", "Salt it"]); XCTAssertEqual(b.plan[0].time, "5 min")
        XCTAssertTrue(Logic.planProgress(b) == (done: 0, total: 2))
        let id = b.plan[0].id
        let when = at("2026-11-25", "11:15")
        Logic.tick(id, in: &b, at: when)
        XCTAssertEqual(b.plan[0].doneAt, when); XCTAssertEqual(b.steps.count, 1)
        XCTAssertTrue(b.steps[0].date == "2026-11-25" && b.steps[0].time == "11:15" && b.steps[0].text == "Chop")
        Logic.tick(id, in: &b, at: at("2026-11-25", "12:00"))        // once only
        XCTAssertEqual(b.steps.count, 1); XCTAssertEqual(b.plan[0].doneAt, when)
        XCTAssertTrue(Logic.planProgress(b) == (done: 1, total: 2))
        Logic.untick(id, in: &b)
        XCTAssertNil(b.plan[0].doneAt); XCTAssertTrue(b.steps.isEmpty)
    }

    // MARK: WebImport

    private let backup = """
    {"app":"fermentlog","version":4,"exportedAt":"2026-11-20T10:00:00.000Z",
     "batches":[{"id":"b_1","name":"Kraut","vegetable":"Kohlrabi","form":"Slices","startDate":"2026-11-01","saltGrams":"25","waterMl":"","roomTempC":20,
        "jarSizeMl":null,"additions":["Turmeric","Garlic"],"vesselType":"Glass jar","weightType":"None","lidType":"Plain lid","remindEveryDays":"3",
        "checkIns":[{"date":"2026-11-04","tasteNote":"Tangy"}],"movedToFridgeDate":"","outcome":null,
        "photos":["data:image/jpeg;base64,/9j/4AAQSkZJRg=="],"notes":"hi","loggedBy":"Anna","createdAt":"2026-11-01T09:30:00.123Z"},
       {"id":"b_2","name":"Old","vegetable":"Carrot","startDate":"2026-10-01","outcome":{"recorded":true,"success":true,"overall":4,"recordedAt":"2026-10-10T10:00:00.000Z","problems":["Mould"]}}],
     "presets":[{"id":"p_1","name":"Mine","vegetable":"Carrot","form":"Cubes","saltGrams":25,"additions":[]}],
     "recipes":[{"id":"r_1","title":"Loaf","category":"Sourdough","ingredients":["flour"],"steps":[{"title":"Mix","detail":"d","time":"5 min"}],"photos":[],"createdAt":"2026-11-02T10:00:00.000Z"}],
     "bakes":[{"id":"k_1","name":"Loaf 1","category":"Sourdough","bakeDate":"2026-11-05","recipeId":"r_1","recipeTitle":"Loaf","ratings":{"crust":"4","overall":null},"problems":[],"loggedBy":"Martin","createdAt":"2026-11-05T10:00:00.000Z"}],
     "bakeLessons":[{"id":"l_1","text":"Longer proof","createdAt":"2026-11-06T10:00:00.000Z","loggedBy":"Anna","recipeId":"r_1","recipeTitle":"Loaf","linkKind":"bake","linkId":"k_1","linkLabel":"Loaf 1"}]}
    """

    func testWebImportReadsTolerantly() throws {
        let res = try WebImport.read(Data(backup.utf8))
        XCTAssertTrue(res.counts == (jars: 2, bakes: 1, recipes: 1, lessons: 1, presets: 1, photos: 1))
        let b = res.data.batches[0]
        XCTAssertEqual(b.id, "b_1"); XCTAssertEqual(b.saltGrams, 25); XCTAssertNil(b.waterMl); XCTAssertNil(b.jarSizeMl); XCTAssertEqual(b.roomTempC, 20)
        XCTAssertEqual(b.remindEveryDays, 3); XCTAssertEqual(b.checkIns.first?.tasteNote, "Tangy"); XCTAssertEqual(b.checkIns.first?.time, "")
        XCTAssertTrue(b.steps.isEmpty); XCTAssertNil(b.outcome)
        XCTAssertEqual(b.photos.count, 1); XCTAssertTrue(b.photos[0].hasSuffix(".jpg")); XCTAssertEqual(res.photos[b.photos[0]]?.count, 10)
        XCTAssertEqual(b.modifiedAt, b.createdAt); XCTAssertTrue(b.createdAt > .distantPast.addingTimeInterval(10))
        let old = res.data.batches[1]
        XCTAssertEqual(old.outcome?.overall, 4); XCTAssertEqual(old.outcome?.problems, ["Mould"]); XCTAssertNotNil(old.outcome?.recordedAt)
        XCTAssertEqual(old.modifiedAt, Date.distantPast.addingTimeInterval(1))
        XCTAssertEqual(res.data.recipes[0].steps[0].time, "5 min")
        XCTAssertEqual(res.data.bakes[0].recipeID, "r_1"); XCTAssertEqual(res.data.bakes[0].ratings.crust, 4); XCTAssertNil(res.data.bakes[0].ratings.overall)
        let l = res.data.lessons[0]
        XCTAssertTrue(l.linkType == "bake" && l.linkID == "k_1" && l.linkLabel == "Loaf 1" && l.recipeID == "r_1")
        // what the web kept in localStorage is derived
        XCTAssertEqual(res.data.settings.customVegetables, ["Kohlrabi"]); XCTAssertEqual(res.data.settings.customSpices, ["Turmeric"])
        XCTAssertEqual(res.data.settings.customForms, [])
        XCTAssertEqual(res.data.settings.people, ["Anna", "Martin"])
    }

    func testWebImportTwiceDoesNotDuplicateAndNativeEditsWin() throws {
        let first = try WebImport.read(Data(backup.utf8))
        var current = WebImport.merge(first.data, into: AppData())
        XCTAssertEqual(current.batches.count, 2)
        var edited = current.batches[0]; edited.name = "Edited natively"; edited.modifiedAt = Date(); current.batches[0] = edited
        let reread = try WebImport.read(Data(backup.utf8))
        let again = WebImport.merge(reread.data, into: current)
        XCTAssertEqual(again.batches.count, 2); XCTAssertEqual(again.recipes.count, 1); XCTAssertEqual(again.bakes.count, 1)
        XCTAssertEqual(again.lessons.count, 1); XCTAssertEqual(again.presets.count, 1)
        XCTAssertEqual(again.batches[0].name, "Edited natively")
        let second = try WebImport.read(Data(backup.utf8))
        XCTAssertEqual(second.photos.keys.sorted(), first.photos.keys.sorted())   // same picture, same file name
    }

    func testWebImportRejectsOtherFiles() {
        XCTAssertThrowsError(try WebImport.read(Data("{\"app\":\"something\",\"batches\":[]}".utf8))) { e in
            XCTAssertEqual(e as? WebImport.Problem, .notAFermentLogBackup)
        }
        XCTAssertThrowsError(try WebImport.read(Data("not json".utf8)))
    }
}
