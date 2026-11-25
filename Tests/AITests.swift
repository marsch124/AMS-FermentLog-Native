import XCTest
@testable import AMSFermentLog

final class AITests: XCTestCase {
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 9))!

    func testExtractJSONCleanAndEmbedded() throws {
        XCTAssertEqual((try AI.extractJSON("{\"a\":1}") as? [String: Int]), ["a": 1])
        XCTAssertEqual((try AI.extractJSON("Sure! ```json\n{\"a\":2}\n``` done") as? [String: Int]), ["a": 2])
        XCTAssertThrowsError(try AI.extractJSON("no json here"))
    }

    func testNormalizeRecipe() {
        let r = AI.normalizeRecipe(["title": "  Loaf ", "category": "Nope", "ingredients": ["flour", "", 3, " salt "],
                                    "steps": [["title": "Mix", "detail": "", "time": "5 min"], ["title": "", "detail": "", "time": ""]]], now: now)
        XCTAssertEqual(r.title, "Loaf")
        XCTAssertEqual(r.category, "Other")
        XCTAssertEqual(r.ingredients, ["flour", "salt"])
        XCTAssertEqual(r.steps.count, 1)
        XCTAssertEqual(AI.normalizeRecipe(["category": "Dairy"]).category, "Dairy")
    }

    func testNormalizeBatch() {
        let b = AI.normalizeBatch(["vegetable": "Carrot", "form": "Sticks", "saltGrams": 30, "waterMl": NSNull(), "lidType": "airlock lid",
                                   "weightType": "ceramic weight", "additions": ["dill", ""], "remindEveryDays": 2], now: now)
        XCTAssertEqual(b.vegetable, "Carrot")
        XCTAssertEqual(b.saltGrams, 30)
        XCTAssertEqual(b.waterMl, 1000)           // null keeps the default
        XCTAssertEqual(b.lidType, "Airlock")
        XCTAssertEqual(b.weightType, "Ceramic weight")
        XCTAssertEqual(b.additions, ["dill"])
        XCTAssertEqual(b.remindEveryDays, 2)
        XCTAssertEqual(AI.normalizeBatch([:], now: now).vegetable, "Carrot")
    }

    func testNormalizeCheckInBadDateFallsBackToToday() {
        XCTAssertEqual(AI.normalizeCheckIn(["date": "2026-07-05", "tasteNote": "  Tangy  "], now: now).date, "2026-07-05")
        XCTAssertEqual(AI.normalizeCheckIn(["date": "2026-07-05", "tasteNote": "  Tangy  "], now: now).tasteNote, "Tangy")
        XCTAssertEqual(AI.normalizeCheckIn(["date": "day 4", "tasteNote": "x"], now: now).date, "2026-07-21")
        XCTAssertEqual(AI.normalizeCheckIn(["tasteNote": "x"], now: now).date, "2026-07-21")
        XCTAssertEqual(AI.normalizeCheckIn(["date": "2026-13-40", "tasteNote": "x"], now: now).date, "2026-07-21")
    }

    func testNormalizeBakeClampsRatings() {
        let b = AI.normalizeBake(["name": "Loaf", "category": "Nope", "bakeDate": "yesterday", "crust": 9, "crumb": 2, "flavour": NSNull(),
                                  "overall": 4.6, "problems": ["Dense crumb", ""], "notes": "good"], now: now)
        XCTAssertEqual(b.category, "Sourdough")
        XCTAssertEqual(b.bakeDate, "2026-07-21")
        XCTAssertEqual(b.ratings.crust, 5)
        XCTAssertEqual(b.ratings.crumb, 2)
        XCTAssertNil(b.ratings.flavour)
        XCTAssertEqual(b.ratings.overall, 5)
        XCTAssertEqual(b.problems, ["Dense crumb"])
        XCTAssertTrue(b.id.hasPrefix("k_"))
    }

    func testRequestShapeAndErrorSentences() throws {
        let req = try AI.makeRequest(system: "s", schema: ["type": "object"], user: "u", key: "k")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "k")
        XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertNil(req.value(forHTTPHeaderField: "anthropic-dangerous-direct-browser-access"))
        XCTAssertEqual(AI.errorSentence(status: 401, body: Data()), "That key was not accepted.")
    }
}
