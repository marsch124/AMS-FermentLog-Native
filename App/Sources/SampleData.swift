import Foundation

/// Sample data for `-sample` (screen tests and pictures). Every date is relative to today, so it always looks current.
extension AppData {
    static var sample: AppData {
        let cal = Calendar.current
        let now = Date()
        func ago(_ days: Int, hour: Int = 9) -> Date {
            let d = cal.date(byAdding: .day, value: -days, to: now) ?? now
            return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
        }
        func day(_ days: Int) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: ago(days))
            return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
        }
        var out = AppData()
        out.settings.people = ["Martin", "Anna"]
        out.settings.activePerson = "Martin"
        out.settings.modifiedAt = now

        // 1. The Cabbage jar: two days old, on a plain lid, with nine Did steps (two burps), a taste check and a plan.
        var cabbage = Batch()
        cabbage.id = "b_sample_cabbage"
        cabbage.name = "Cabbage jar"; cabbage.vegetable = "Cabbage"; cabbage.form = "Chopped"
        cabbage.startDate = day(2); cabbage.saltGrams = 20; cabbage.waterMl = 0; cabbage.roomTempC = 19; cabbage.jarSizeMl = 1500
        cabbage.additions = ["Caraway seeds", "Juniper berries"]
        cabbage.vesselType = "Glass jar"; cabbage.weightType = "Glass weight"; cabbage.lidType = "Plain lid"
        cabbage.recipeID = "r_sample_sauerkraut"; cabbage.recipeTitle = "Sauerkraut"
        cabbage.loggedBy = "Martin"
        cabbage.steps = [
            Step(date: day(2), time: "09:10", text: "Shredded 1.2 kg of cabbage"),
            Step(date: day(2), time: "09:25", text: "Salted and massaged until it released its juice"),
            Step(date: day(2), time: "09:40", text: "Packed it into the jar"),
            Step(date: day(2), time: "09:45", text: "Added the glass weight, brine covers the cabbage"),
            Step(date: day(2), time: "09:50", text: "Closed the lid and put it on the counter"),
            Step(date: day(1), time: "08:05", text: "Burped the jar", kind: "burp"),
            Step(date: day(1), time: "19:30", text: "Pressed the cabbage down again"),
            Step(date: day(0), time: "08:00", text: "Burped the jar", kind: "burp"),
            Step(date: day(0), time: "08:10", text: "Bubbles rising, smells fresh and sour"),
        ]
        cabbage.checkIns = [CheckIn(date: day(0), time: "08:15", tasteNote: "Still crunchy, a little salty, not sour yet")]
        var p1 = PlanStep(title: "Burp the jar", detail: "Open the lid for a second, then close it again.", time: "daily")
        p1.doneAt = ago(1)
        cabbage.plan = [p1,
                        PlanStep(title: "Taste test", detail: "Take a forkful and note how sour it is.", time: "day 5"),
                        PlanStep(title: "Move to the fridge", detail: "When it tastes right, store it cold.", time: "day 7-14")]
        cabbage.remindEveryDays = 3
        cabbage.createdAt = ago(2); cabbage.modifiedAt = ago(0)

        // 2. A jar in the fridge.
        var carrots = Batch()
        carrots.id = "b_sample_carrots"
        carrots.name = "Carrot sticks"; carrots.vegetable = "Carrot"; carrots.form = "Sticks"
        carrots.startDate = day(9); carrots.saltGrams = 25; carrots.waterMl = 1000; carrots.roomTempC = 20; carrots.jarSizeMl = 1000
        carrots.additions = ["Garlic", "Dill"]
        carrots.lidType = "Burping / self-venting lid"; carrots.loggedBy = "Anna"
        carrots.movedToFridgeDate = day(2)
        carrots.steps = [
            Step(date: day(9), time: "18:00", text: "Packed carrot sticks with garlic and dill"),
            Step(date: day(6), time: "08:00", text: "Bubbles stopped, smells sweet and tangy"),
            Step(date: day(2), time: "17:00", text: "Moved to the fridge"),
        ]
        carrots.checkIns = [CheckIn(date: day(6), time: "08:10", tasteNote: "Crisp and lightly sour")]
        carrots.createdAt = ago(9); carrots.modifiedAt = ago(2)

        // 3. A finished jar with its outcome.
        var beets = Batch()
        beets.id = "b_sample_beets"
        beets.name = "Beetroot"; beets.vegetable = "Beetroot"; beets.form = "Sliced"
        beets.startDate = day(30); beets.saltGrams = 30; beets.waterMl = 1000; beets.roomTempC = 21; beets.jarSizeMl = 1000
        beets.lidType = "Plain lid"; beets.loggedBy = "Martin"; beets.movedToFridgeDate = day(21)
        beets.steps = [
            Step(date: day(30), text: "Sliced and packed the beetroot"),
            Step(date: day(21), text: "Moved to the fridge"),
            Step(date: day(3), text: "Finished the last of it"),
        ]
        var outcome = Outcome()
        outcome.recorded = true; outcome.success = true
        outcome.taste = 4; outcome.sourness = 3; outcome.crunch = 3; outcome.overall = 4
        outcome.problems = []; outcome.recordedAt = ago(3)
        beets.outcome = outcome
        beets.createdAt = ago(30); beets.modifiedAt = ago(3)

        // 4. A jar with an airlock lid.
        var radish = Batch()
        radish.id = "b_sample_radish"
        radish.name = "Radish pickles"; radish.vegetable = "Radish"; radish.form = "Whole"
        radish.startDate = day(4); radish.saltGrams = 18; radish.waterMl = 700; radish.roomTempC = 22; radish.jarSizeMl = 750
        radish.additions = ["Chilli"]
        radish.lidType = "Airlock lid"; radish.loggedBy = "Anna"
        radish.steps = [
            Step(date: day(4), time: "12:00", text: "Packed whole radishes with chilli"),
            Step(date: day(3), time: "12:30", text: "Airlock bubbling every few seconds"),
        ]
        radish.createdAt = ago(4); radish.modifiedAt = ago(3)
        out.batches = [cabbage, carrots, beets, radish]

        // Pictures of the charts ("-charts"): five more finished, rated jars, so Insights has something to draw.
        if PictureArgs.has("charts") {
            func done(_ n: Int, _ name: String, _ veg: String, _ form: String, _ lid: String, salt: Double, temp: Double, start: Int, days: Int, stars: Int, problems: [String] = []) -> Batch {
                var b = Batch()
                b.id = "b_sample_chart_\(n)"; b.name = name; b.vegetable = veg; b.form = form; b.lidType = lid
                b.saltGrams = salt; b.waterMl = 1000; b.roomTempC = temp
                b.startDate = day(start); b.movedToFridgeDate = day(start - days)
                var o = Outcome()
                o.recorded = true; o.success = stars >= 3
                o.taste = stars; o.sourness = max(1, stars - 1); o.crunch = stars; o.overall = stars
                o.problems = problems; o.recordedAt = ago(start - days - 1)
                b.outcome = o
                b.createdAt = ago(start); b.modifiedAt = ago(start - days - 1)
                return b
            }
            out.batches += [
                done(1, "Surkål", "Cabbage", "Shredded", "Airlock lid", salt: 24, temp: 20, start: 120, days: 21, stars: 5),
                done(2, "Kimchi", "Cabbage", "Chopped", "Airlock lid", salt: 22, temp: 20, start: 90, days: 14, stars: 4),
                done(3, "Carrot coins", "Carrot", "Slices", "Burping / self-venting lid", salt: 29, temp: 22, start: 70, days: 9, stars: 4, problems: ["Too salty"]),
                done(4, "Garlic carrots", "Carrot", "Sticks", "Plain lid", salt: 16, temp: 23, start: 50, days: 6, stars: 2, problems: ["Mushy / soft", "Kahm yeast"]),
                done(5, "Red cabbage", "Cabbage", "Shredded", "Plain lid", salt: 35, temp: 18, start: 40, days: 12, stars: 3, problems: ["Too salty"]),
            ]
        }

        // Recipes: the web app's sourdough example, and a sauerkraut.
        var sourdough = Recipe()
        sourdough.id = "r_sample_sourdough"
        sourdough.title = "Everyday Sourdough Loaf"; sourdough.category = "Sourdough"
        sourdough.description = "A simple naturally-leavened loaf with an open crumb and a crisp, deep-brown crust. Mostly waiting — very little hands-on work."
        sourdough.ingredients = [
            "100 g active sourdough starter (bubbly, doubled)",
            "350 g water, room temperature",
            "500 g bread flour",
            "10 g fine sea salt",
            "25 g water (to dissolve the salt)",
        ]
        sourdough.equipment = ["Kitchen scale", "Large mixing bowl", "Banneton / proofing basket", "Dutch oven (or a baking stone + lid)", "Lame or a sharp knife for scoring"]
        sourdough.activeTime = "~45 minutes hands-on"; sourdough.totalTime = "~24 hours (mostly hands-off)"
        sourdough.steps = [
            RecipeStep(title: "Feed the starter", detail: "Feed your starter and let it grow until bubbly and roughly doubled.", time: "4–6 h (or overnight)"),
            RecipeStep(title: "Autolyse", detail: "Mix the flour and 350 g water until no dry bits remain. Cover and rest to hydrate.", time: "1 h"),
            RecipeStep(title: "Mix", detail: "Add the starter and the salt dissolved in 25 g water. Squeeze and fold until smooth.", time: "15 min"),
            RecipeStep(title: "Bulk fermentation", detail: "Stretch and fold every 30 min for the first 2 h, then let it rise until puffy and ~50% larger.", time: "4–6 h at ~22°C"),
            RecipeStep(title: "Shape", detail: "Pre-shape into a round, bench-rest, then shape tightly and place seam-up in a floured banneton.", time: "30 min"),
            RecipeStep(title: "Cold proof", detail: "Cover and refrigerate overnight to develop flavour and firm up for scoring.", time: "12–16 h"),
            RecipeStep(title: "Bake", detail: "Preheat the Dutch oven to 230°C. Turn out the loaf, score, bake covered, then uncovered to brown.", time: "20 min covered + 25 min uncovered"),
        ]
        sourdough.storage = "Cool completely (at least 1 h) before slicing — the crumb sets as it cools. Keep cut-side down on a board at room temperature for 2–3 days, or slice and freeze for up to 3 months. Refresh slices straight from the freezer in a toaster."
        sourdough.createdAt = ago(40); sourdough.modifiedAt = ago(40)

        var kraut = Recipe()
        kraut.id = "r_sample_sauerkraut"
        kraut.title = "Sauerkraut"; kraut.category = "Vegetable ferment"
        kraut.description = "Cabbage and salt, nothing else needed. Crunchy, sour and alive after one to three weeks on the counter."
        kraut.ingredients = ["1 kg white cabbage, shredded", "20 g fine sea salt (2% of the cabbage)", "1 tsp caraway seeds (optional)"]
        kraut.equipment = ["Kitchen scale", "Large bowl", "1.5 litre glass jar", "Glass weight", "Lid or airlock"]
        kraut.activeTime = "~30 minutes hands-on"; kraut.totalTime = "1–3 weeks"
        kraut.steps = [
            RecipeStep(title: "Shred", detail: "Remove the outer leaves, quarter and core the cabbage, then shred it finely.", time: "10 min"),
            RecipeStep(title: "Salt", detail: "Weigh the cabbage and add 2% salt. Mix well in the bowl.", time: "2 min"),
            RecipeStep(title: "Massage", detail: "Squeeze and knead until it turns watery and shrinks to about half.", time: "10 min"),
            RecipeStep(title: "Pack", detail: "Press the cabbage into the jar a handful at a time, leaving a hand's width at the top.", time: "5 min"),
            RecipeStep(title: "Weigh down", detail: "Pour in the juice. The cabbage must be under the brine; add the weight.", time: "2 min"),
            RecipeStep(title: "Close", detail: "Close the lid loosely, or fit the airlock. Keep it at 18–22°C, out of the sun.", time: "1 min"),
            RecipeStep(title: "Burp and press", detail: "Daily for the first week: open the lid briefly and press the cabbage back under the brine.", time: "daily"),
            RecipeStep(title: "Taste", detail: "From day 7, taste it every few days. Ready when it is pleasantly sour.", time: "day 7–21"),
            RecipeStep(title: "Fridge", detail: "Move to the fridge to slow it down. It keeps for months.", time: "1 min"),
        ]
        kraut.storage = "Keep in the fridge, cabbage under the brine, for up to 6 months."
        kraut.createdAt = ago(20); kraut.modifiedAt = ago(20)
        out.recipes = [sourdough, kraut]

        // Bakes
        var bake1 = Bake()
        bake1.id = "k_sample_1"
        bake1.name = "Saturday loaf"; bake1.category = "Sourdough"; bake1.bakeDate = day(5)
        bake1.recipeID = sourdough.id; bake1.recipeTitle = sourdough.title
        bake1.ratings.crust = 4; bake1.ratings.crumb = 3; bake1.ratings.flavour = 4; bake1.ratings.overall = 4
        bake1.problems = ["Dense crumb"]; bake1.notes = "Rose well, but the crumb was a little tight. Longer bulk next time."
        bake1.loggedBy = "Martin"; bake1.createdAt = ago(5); bake1.modifiedAt = ago(5)
        var bake2 = Bake()
        bake2.id = "k_sample_2"
        bake2.name = "Seeded sourdough"; bake2.category = "Sourdough"; bake2.bakeDate = day(12)
        bake2.recipeID = sourdough.id; bake2.recipeTitle = sourdough.title
        bake2.ratings.crust = 5; bake2.ratings.crumb = 5; bake2.ratings.flavour = 4; bake2.ratings.overall = 5
        bake2.notes = "Added sunflower and pumpkin seeds. Best one so far."
        bake2.loggedBy = "Anna"; bake2.createdAt = ago(12); bake2.modifiedAt = ago(12)
        out.bakes = [bake1, bake2]

        // Lessons
        var l1 = Lesson()
        l1.id = "l_sample_1"
        l1.text = "Press the cabbage down again after the first day; it keeps everything under the brine."
        l1.loggedBy = "Martin"; l1.linkType = "batch"; l1.linkID = cabbage.id; l1.linkLabel = cabbage.title
        l1.recipeID = kraut.id; l1.recipeTitle = kraut.title
        l1.createdAt = ago(1); l1.modifiedAt = ago(1)
        var l2 = Lesson()
        l2.id = "l_sample_2"
        l2.text = "Give the bulk fermentation an extra hour when the kitchen is cold."
        l2.loggedBy = "Anna"; l2.linkType = "bake"; l2.linkID = bake1.id; l2.linkLabel = bake1.name
        l2.recipeID = sourdough.id; l2.recipeTitle = sourdough.title
        l2.createdAt = ago(5); l2.modifiedAt = ago(5)
        out.lessons = [l1, l2]

        // One preset
        var preset = Preset()
        preset.id = "p_sample_1"
        preset.name = "Everyday kraut"; preset.vegetable = "Cabbage"; preset.form = "Shredded"
        preset.saltGrams = 20; preset.waterMl = 0; preset.roomTempC = 20; preset.jarSizeMl = 1500
        preset.additions = ["Caraway seeds"]
        preset.vesselType = "Glass jar"; preset.weightType = "Glass weight"; preset.lidType = "Plain lid"; preset.remindEveryDays = 3
        preset.modifiedAt = ago(15)
        out.presets = [preset]

        out.savedAt = now
        return out
    }
}

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// A made-up picture for screenshots ("-samplePhoto"): a green-to-cream glass with darker shreds and a few bubbles.
enum SamplePhoto {
    /// `shade` 0…1 turns the cabbage from green to purple, so several sample pictures look different (6.7).
    static func jpeg(width: Int = 600, height: Int = 760, shade: Double = 0) -> Data? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let w = CGFloat(width), h = CGFloat(height)
        // Background: a warm kitchen wall.
        ctx.setFillColor(CGColor(red: 0.93, green: 0.86, blue: 0.76, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        // The glass full of pale green cabbage.
        let glass = CGRect(x: w * 0.18, y: h * 0.08, width: w * 0.64, height: h * 0.74)
        let colors = [CGColor(red: 0.62 + 0.1 * shade, green: 0.74 - 0.45 * shade, blue: 0.40 + 0.25 * shade, alpha: 1), CGColor(red: 0.90, green: 0.92 - 0.2 * shade, blue: 0.70 + 0.1 * shade, alpha: 1)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            ctx.saveGState(); ctx.addPath(CGPath(roundedRect: glass, cornerWidth: 40, cornerHeight: 40, transform: nil)); ctx.clip()
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: glass.minY), end: CGPoint(x: 0, y: glass.maxY), options: [])
            ctx.setStrokeColor(CGColor(red: 0.42, green: 0.55, blue: 0.25, alpha: 0.55)); ctx.setLineWidth(5); ctx.setLineCap(.round)
            for k in 0..<26 {
                let x = glass.minX + CGFloat((k * 37) % 300) / 300 * glass.width
                let y = glass.minY + CGFloat((k * 53) % 400) / 400 * glass.height * 0.8
                ctx.move(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x + 40, y: y + CGFloat(k % 5) * 6 - 12))
            }
            ctx.strokePath()
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.6))
            for k in 0..<9 { ctx.fillEllipse(in: CGRect(x: glass.minX + CGFloat(k * 41 % 330), y: glass.minY + 30 + CGFloat(k * 67 % 420), width: 12, height: 12)) }
            ctx.restoreGState()
        }
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.8)); ctx.setLineWidth(8)
        ctx.addPath(CGPath(roundedRect: glass, cornerWidth: 40, cornerHeight: 40, transform: nil)); ctx.strokePath()
        // The lid.
        ctx.setFillColor(CGColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1))
        ctx.fill(CGRect(x: glass.minX + 30, y: glass.maxY - 4, width: glass.width - 60, height: 60))
        guard let image = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}
