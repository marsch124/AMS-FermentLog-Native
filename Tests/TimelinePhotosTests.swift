import XCTest
@testable import AMSFermentLog

/// 6.7: pictures on Timeline lines — adding, the photo story, the head picture, the files that count, old files, text words.
final class TimelinePhotosTests: XCTestCase {
    private func jar() -> Batch {
        var b = Batch(); b.startDate = "2026-11-23"
        b.steps = [Step(date: "2026-11-23", time: "10:30", text: "Packed carrots", photos: ["a.jpg", "b.jpg"])]
        b.checkIns = [CheckIn(date: "2026-11-25", time: "08:12", tasteNote: "tangy, still crunchy", photos: ["c.jpg"])]
        return b
    }

    func testAddLineWithPictures() {
        let b = Batch()
        XCTAssertNil(Logic.addingLine(to: b, kind: .did, text: "  ", photos: [], date: "2026-11-26", time: "09:00"))
        XCTAssertNil(Logic.addingLine(to: b, kind: .taste, text: "", photos: [], date: "2026-11-26", time: "09:00"))
        // A picture alone is a line.
        let only = Logic.addingLine(to: b, kind: .did, text: "", photos: ["p.jpg"], date: "2026-11-26", time: "09:00")
        XCTAssertEqual(only?.steps.count, 1); XCTAssertEqual(only?.steps.first?.text, ""); XCTAssertEqual(only?.steps.first?.photos, ["p.jpg"])
        // Several lines of words: the pictures go with the last one.
        let list = Logic.addingLine(to: b, kind: .did, text: "1. Chopped\n2. Salted", photos: ["p.jpg"], date: "2026-11-26", time: "09:00")
        XCTAssertEqual(list?.steps.map(\.text), ["Chopped", "Salted"]); XCTAssertEqual(list?.steps.map(\.photos), [[], ["p.jpg"]])
        // A taste test with only a picture.
        let taste = Logic.addingLine(to: b, kind: .taste, text: "", photos: ["t.jpg"], date: "2026-11-26", time: "09:00")
        XCTAssertEqual(taste?.checkIns.first?.tasteNote, ""); XCTAssertEqual(taste?.checkIns.first?.photos, ["t.jpg"])
    }

    func testPhotoStoryOrderAndCaptions() {
        var b = jar()
        b.steps.append(Step(date: "2026-11-25", time: "08:20", text: "", photos: ["d.jpg"]))
        let now = Logic.date(fromDay: "2026-11-26")!
        let story = Logic.photoStory(b, now: now)
        XCTAssertEqual(story.map(\.name), ["a.jpg", "b.jpg", "c.jpg", "d.jpg"])
        XCTAssertEqual(story[0].caption, "Day 1 \u{00b7} \(Human.day("2026-11-23", now: now)) 10:30 \u{2014} Packed carrots")
        XCTAssertEqual(story[2].caption, "Day 3 \u{00b7} \(Human.day("2026-11-25", now: now)) 08:12 \u{2014} Taste: tangy, still crunchy")
        XCTAssertEqual(story[3].caption, "Day 3 \u{00b7} \(Human.day("2026-11-25", now: now)) 08:20")
    }

    func testHeadPhotoIsNewest() {
        var b = jar()
        XCTAssertEqual(Logic.headPhoto(b), "c.jpg")                 // the newest Timeline picture
        b.steps = []; b.checkIns = []; b.photos = ["own.jpg"]
        XCTAssertEqual(Logic.headPhoto(b), "own.jpg")               // else the jar's own first picture
        b.photos = []
        XCTAssertNil(Logic.headPhoto(b))                            // else the drawn jar
    }

    @MainActor func testPhotoFilesIncludeLinePictures() {
        var d = AppData(); d.batches = [jar()]
        XCTAssertEqual(Store.photoFiles(in: d), ["a.jpg", "b.jpg", "c.jpg"])
    }

    func testOldLinesReadWithoutPictures() throws {
        let old = #"{"id":"s1","date":"2026-11-23","time":"10:30","text":"Packed"}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder.app.decode(Step.self, from: old).photos, [])
        let oldTaste = #"{"id":"c1","date":"2026-11-23","tasteNote":"salty"}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder.app.decode(CheckIn.self, from: oldTaste).photos, [])
        XCTAssertEqual(AppData.currentFormat, 2)
    }

    func testLineWordsInText() {
        let b = jar()
        XCTAssertTrue(Logic.stepsText(b).hasSuffix("Packed carrots (2 pictures)"))
        let e = TimelineEntry(kind: .did, id: "x", date: "", time: "", text: "", isBurp: false, photos: ["p.jpg"])
        XCTAssertEqual(Logic.lineWords(e), "(1 picture)")
    }
}
