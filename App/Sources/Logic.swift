import Foundation

// The pure rules of FermentLog, ported from the web app's js/model.js (same rules, same edge cases),
// plus the native-only rules: burp alarm, "save a jar's steps as a recipe" and the recipe tick-off list.
// Foundation only. All dates are the device's LOCAL day/time (the web app used UTC in places).

// MARK: - Small value types

enum JarStatus: String, Equatable { case fermenting, fridge, done }

/// One line of a jar's Timeline: something you did, or a taste test.
struct TimelineEntry: Equatable, Identifiable {
    enum Kind: String { case did, taste }
    var kind: Kind
    /// The id of the Step or CheckIn this line comes from.
    var id: String
    var date: String
    var time: String
    var text: String
    /// True for a "Did" line written by the Burped button / alarm.
    var isBurp: Bool
}

struct XYPoint: Equatable { var x: Double; var y: Double; var name: String }
struct LabelValue: Equatable { var label: String; var value: Double; var count: Int }
struct LabelCount: Equatable { var label: String; var value: Int }

/// The numbers the Insights screen shows (same members as the web's summarizeStats object).
struct BatchStats {
    var vegetables: [String]
    var total: Int
    var active: Int
    var finished: Int
    var successRate: Double?
    var avgRating: Double?
    var ratingVsBrine: [XYPoint]
    var ratingVsTemp: [XYPoint]
    var ratingVsDays: [XYPoint]
    var ratingOverTime: [XYPoint]
    var byVegetable: [LabelValue]
    var byForm: [LabelValue]
    var byLid: [LabelValue]
    var problems: [LabelCount]
    var bestBatch: Batch?
    var bestRating: Double?
}

struct BakeStats {
    var total: Int
    var rated: Int
    var avgOverall: Double?
    var byRecipe: [LabelValue]
    var byCategory: [LabelValue]
    var problems: [LabelCount]
    var ratingOverTime: [XYPoint]
    var bestBake: Bake?
    var bestRating: Double?
}

struct Recommendation: Equatable {
    var count: Int
    var brine: Double?
    var tempC: Double?
    var days: Int?
    var lid: String?
    var vegetable: String?
}

struct SearchResults {
    var batches: [Batch]
    var bakes: [Bake]
    var recipes: [Recipe]
    var total: Int { batches.count + bakes.count + recipes.count }
}

enum Cell: Equatable { case text(String), number(Double), empty }

struct Sheet {
    var name: String
    var columns: [(header: String, width: Double)]
    var rows: [[Cell]]
}

// MARK: - Logic

enum Logic {

    // MARK: Lists

    static let VEGETABLES = ["Carrot", "Cabbage", "Cucumber", "Beetroot", "Cauliflower", "Green beans", "Radish", "Garlic", "Onion", "Pepper"]
    static let FORMS = ["Sticks", "Slices", "Rounds", "Cubes", "Spears", "Wedges", "Shredded", "Grated", "Chopped", "Florets", "Whole", "Halved"]
    static let LID_TYPES = ["Airlock", "Burping / self-venting lid", "Plain lid", "Cloth / open"]
    static let WEIGHT_TYPES = ["Glass weight", "Ceramic weight", "Cabbage leaf", "Smaller jar", "None"]
    static let PROBLEMS = ["Mould", "Kahm yeast", "Mushy / soft", "Too salty", "Not sour enough", "Off smell"]
    static let COMMON_SPICES = ["Garlic", "Dill", "Mustard seed", "Black pepper", "Bay leaf", "Ginger", "Chilli"]
    static let BAKE_CATEGORIES = ["Sourdough", "Bread", "Other"]
    static let BAKE_PROBLEMS = ["Dense crumb", "Gummy", "Flat / didn\u{2019}t rise", "Over-proofed", "Under-proofed", "Burnt", "Pale crust"]
    static let RECIPE_CATEGORIES = ["Sourdough", "Vegetable ferment", "Drink / kombucha", "Dairy", "Other"]
    static let BRINE_MIN = 2.0
    static let BRINE_MAX = 3.0
    static let DEFAULT_REMIND_DAYS = 3

    /// Split a legacy combined name ("Carrot sticks") into vegetable + form, only when the last word is a known form.
    static func splitVegForm(_ name: String, forms: [String] = FORMS) -> (vegetable: String, form: String) {
        let raw = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.contains(" ") { return (raw, "") }
        let parts = raw.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let last = parts.last, let match = forms.first(where: { $0.lowercased() == last.lowercased() }) else { return (raw, "") }
        return (parts.dropLast().joined(separator: " "), match)
    }

    /// Vegetables seen in past jars that aren't built-in: sorted, de-duplicated.
    static func usedVegetables(_ batches: [Batch]) -> [String] {
        let builtin = Set(VEGETABLES)
        return Set(batches.map(\.vegetable).filter { !$0.isEmpty && !builtin.contains($0) }).sorted()
    }

    /// Built-in vegetables first (original order), then any unique extras as given.
    static func mergeVegetables(_ extra: [String] = []) -> [String] { unique(VEGETABLES + extra) }

    /// Spices seen in past jars that aren't built-in: sorted, de-duplicated.
    static func usedSpices(_ batches: [Batch]) -> [String] {
        let builtin = Set(COMMON_SPICES)
        return Set(batches.flatMap(\.additions).filter { !$0.isEmpty && !builtin.contains($0) }).sorted()
    }

    static func mergeSpices(_ extra: [String] = []) -> [String] { unique(COMMON_SPICES + extra) }

    /// Replace every occurrence of oldName with newName; de-duplicate; drop blanks.
    static func renamedList(_ list: [String], _ oldName: String, _ newName: String) -> [String] {
        unique(list.map { $0 == oldName ? newName : $0 })
    }

    /// Remove every occurrence of name from a list.
    static func withoutItem(_ list: [String], _ name: String) -> [String] { list.filter { $0 != name } }

    private static func unique(_ list: [String]) -> [String] {
        var seen = Set<String>(); var out: [String] = []
        for s in list where !s.isEmpty && !seen.contains(s) { seen.insert(s); out.append(s) }
        return out
    }

    // MARK: Local date helpers

    private static var cal: Calendar { Calendar.current }

    /// "yyyy-MM-dd" in the device's time zone.
    static func isoDay(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "HH:mm" in the device's time zone.
    static func clock(_ d: Date) -> String {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func parseDay(_ s: String) -> DateComponents? {
        let p = s.trimmingCharacters(in: .whitespaces).prefix(10).split(separator: "-", omittingEmptySubsequences: false)
        guard p.count == 3, let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]), p[0].count == 4 else { return nil }
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        guard let date = cal.date(from: c) else { return nil }
        let back = cal.dateComponents([.year, .month, .day], from: date)
        return back.year == y && back.month == m && back.day == d ? c : nil
    }

    /// The moment of a stored day + clock time ("" time = midnight); nil when either is unreadable.
    static func date(fromDay day: String, time: String = "") -> Date? {
        guard var c = parseDay(day) else { return nil }
        let t = time.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty {
            let p = t.split(separator: ":", omittingEmptySubsequences: false)
            guard p.count >= 2, let h = Int(p[0]), let m = Int(p[1]), (0..<24).contains(h), (0..<60).contains(m) else { return nil }
            c.hour = h; c.minute = m
        }
        return cal.date(from: c)
    }

    private static func addDays(_ day: String, _ n: Int) -> String? {
        guard let d = date(fromDay: day), let r = cal.date(byAdding: .day, value: n, to: d) else { return nil }
        return isoDay(r)
    }

    // MARK: Brine, days, status

    /// Salt concentration as % by weight (1 ml water ~ 1 g). nil when an input is missing/invalid.
    static func computeBrinePercent(salt: Double?, water: Double?) -> Double? {
        guard let s = salt, let w = water, s.isFinite, w.isFinite, s >= 0, w >= 0 else { return nil }
        // No water = a dry-salted ferment (sauerkraut): there is no brine to measure, so no figure
        // (the web app said "100%" here, which meant nothing).
        if w <= 0 { return nil }
        return s / (s + w) * 100
    }

    static func isBrineInRange(_ brinePercent: Double?) -> Bool {
        guard let b = brinePercent else { return false }
        return b >= BRINE_MIN && b <= BRINE_MAX
    }

    /// Whole days between two days (or now). Never negative; nil if start missing/unreadable.
    static func daysBetween(start: String, end: String?, now: Date = Date()) -> Int? {
        guard !start.isEmpty, let s = date(fromDay: start) else { return nil }
        let e: Date
        if let end, !end.isEmpty { guard let x = date(fromDay: end) else { return nil }; e = x } else { e = cal.startOfDay(for: now) }
        let n = cal.dateComponents([.day], from: cal.startOfDay(for: s), to: cal.startOfDay(for: e)).day ?? 0
        return max(0, n)
    }

    /// Days a jar spent fermenting: start to fridge day / outcome day / now.
    static func fermentDays(_ b: Batch, now: Date = Date()) -> Int? {
        var end: String? = nil
        if !b.movedToFridgeDate.isEmpty { end = b.movedToFridgeDate }
        else if let r = b.outcome?.recordedAt { end = isoDay(r) }
        return daysBetween(start: b.startDate, end: end, now: now)
    }

    static func batchStatus(_ b: Batch) -> JarStatus {
        if b.outcome?.recorded == true { return .done }
        if !b.movedToFridgeDate.isEmpty { return .fridge }
        return .fermenting
    }

    static func statusLabel(_ s: JarStatus) -> String {
        switch s { case .fermenting: return "Fermenting"; case .fridge: return "In fridge"; case .done: return "Done" }
    }

    /// The explicit overall rating, else the average of taste/sourness/crunch; nil without any.
    static func overallRating(_ b: Batch) -> Double? {
        guard let o = b.outcome else { return nil }
        if let v = o.overall { return Double(v) }
        let parts = [o.taste, o.sourness, o.crunch].compactMap { $0 }.map(Double.init)
        return parts.isEmpty ? nil : parts.reduce(0, +) / Double(parts.count)
    }

    static func ratingStars(_ n: Double?) -> String {
        guard let n, n.isFinite else { return "\u{2014}" }
        let full = max(0, min(5, Int(n.rounded())))
        return String(repeating: "\u{2605}", count: full) + String(repeating: "\u{2606}", count: 5 - full)
    }

    // MARK: Taste-test reminder (counted from the last taste check-in, never from steps)

    static func nextCheckDue(_ b: Batch) -> String? {
        guard batchStatus(b) == .fermenting, b.remindEveryDays > 0 else { return nil }
        let base = b.checkIns.map(\.date).filter { !$0.isEmpty }.max() ?? b.startDate
        if base.isEmpty { return nil }
        return addDays(base, b.remindEveryDays)
    }

    static func isCheckDue(_ b: Batch, today: Date = Date()) -> Bool {
        guard let due = nextCheckDue(b) else { return false }
        return isoDay(today) >= due
    }

    static func dueBatches(_ batches: [Batch], today: Date = Date()) -> [Batch] { batches.filter { isCheckDue($0, today: today) } }

    // MARK: Timeline

    private static let stepLineRegex = try! NSRegularExpression(pattern: "^[\\s\u{2022}\u{00b7}*\\-\u{2013}\u{2014}]*(?:\\d{1,3}[.)](?!\\d)\\s*)?")

    /// One step per line; list numbers ("3.", "4)") and bullets removed, blanks dropped; "2% salt" and "2.5 kg" kept.
    static func parseStepLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines).compactMap { line in
            let ns = line as NSString
            let m = stepLineRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length))
            let rest = m.map { ns.substring(from: $0.range.length) } ?? line
            let t = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
    }

    static func stepsFromText(_ text: String, date: String, time: String = "") -> [Step] {
        parseStepLines(text).map { Step(date: date, time: time, text: $0) }
    }

    /// The jar's whole diary, oldest first. A line without a time ends its day; equal keys keep entry order.
    static func timelineEntries(_ b: Batch) -> [TimelineEntry] {
        var out: [TimelineEntry] = []
        for s in b.steps { out.append(TimelineEntry(kind: .did, id: s.id, date: s.date, time: s.time, text: s.text, isBurp: s.kind == "burp")) }
        for c in b.checkIns { out.append(TimelineEntry(kind: .taste, id: c.id, date: c.date, time: c.time, text: c.tasteNote, isBurp: false)) }
        func key(_ e: TimelineEntry) -> String { "\(e.date) \(e.time.isEmpty ? "99:99" : e.time)" }
        return out.enumerated().sorted { l, r in
            let a = key(l.element), c = key(r.element)
            return a != c ? a < c : l.offset < r.offset
        }.map(\.element)
    }

    /// The "Did" lines as plain text ("2026-11-25 10:30 \u{2014} Chopped the cabbage"), for sharing and export.
    static func stepsText(_ b: Batch) -> String {
        timelineEntries(b).filter { $0.kind == .did }
            .map { "\([$0.date, $0.time].filter { !$0.isEmpty }.joined(separator: " ")) \u{2014} \($0.text)" }
            .joined(separator: "\n")
    }

    // MARK: Stats

    private static func round1(_ n: Double) -> Double { (n * 10).rounded() / 10 }

    private static func median(_ nums: [Double]) -> Double? {
        let s = nums.sorted()
        if s.isEmpty { return nil }
        let mid = s.count / 2
        return s.count % 2 == 1 ? s[mid] : (s[mid - 1] + s[mid]) / 2
    }

    /// The most frequent item; on a tie the one seen first.
    private static func mode(_ items: [String]) -> String? {
        var counts: [String: Int] = [:]; var order: [String] = []
        for i in items { if counts[i] == nil { order.append(i) }; counts[i, default: 0] += 1 }
        var best: String?; var bestN = 0
        for k in order where counts[k]! > bestN { best = k; bestN = counts[k]! }
        return best
    }

    private static func stableSorted<T>(_ a: [T], _ less: (T, T) -> Bool) -> [T] {
        a.enumerated().sorted { l, r in
            if less(l.element, r.element) { return true }
            if less(r.element, l.element) { return false }
            return l.offset < r.offset
        }.map(\.element)
    }

    private static func avgBy<T>(_ rated: [(item: T, rating: Double)], _ key: (T) -> String) -> [LabelValue] {
        var buckets: [String: [Double]] = [:]; var order: [String] = []
        for r in rated {
            let k = key(r.item)
            if k.isEmpty { continue }
            if buckets[k] == nil { order.append(k) }
            buckets[k, default: []].append(r.rating)
        }
        let rows = order.map { k -> LabelValue in
            let v = buckets[k]!
            return LabelValue(label: k, value: round1(v.reduce(0, +) / Double(v.count)), count: v.count)
        }
        return stableSorted(rows) { $0.value > $1.value }
    }

    private static func countProblems(_ lists: [[String]]) -> [LabelCount] {
        var counts: [String: Int] = [:]; var order: [String] = []
        for l in lists { for p in l { if counts[p] == nil { order.append(p) }; counts[p, default: 0] += 1 } }
        return stableSorted(order.map { LabelCount(label: $0, value: counts[$0]!) }) { $0.value > $1.value }
    }

    /// A recommended "recipe" from the best jars (overall >= threshold); nil until two good jars exist.
    static func recommendation(_ batches: [Batch], threshold: Double = 4, now: Date = Date()) -> Recommendation? {
        let good = batches.filter { batchStatus($0) == .done && (overallRating($0) ?? 0) >= threshold }
        if good.count < 2 { return nil }
        let brines = good.compactMap { computeBrinePercent(salt: $0.saltGrams, water: $0.waterMl) }
        let temps = good.compactMap(\.roomTempC)
        let days = good.compactMap { fermentDays($0, now: now) }.map(Double.init)
        return Recommendation(
            count: good.count,
            brine: median(brines).map(round1),
            tempC: median(temps).map(round1),
            days: median(days).map { Int($0.rounded()) },
            lid: mode(good.map(\.lidType).filter { !$0.isEmpty }),
            vegetable: mode(good.map(\.vegetable).filter { !$0.isEmpty }))
    }

    static func summarizeStats(_ batches: [Batch], vegetable: String? = nil, now: Date = Date()) -> BatchStats {
        let vegetables = Set(batches.map(\.vegetable).filter { !$0.isEmpty }).sorted()
        let list = (vegetable?.isEmpty == false) ? batches.filter { $0.vegetable == vegetable } : batches
        let finished = list.filter { batchStatus($0) == .done }
        let successful = finished.filter { $0.outcome?.success == true }.count
        let successRate: Double? = finished.isEmpty ? nil : Double(successful) / Double(finished.count)

        let ratedUnsorted: [(item: Batch, rating: Double)] = finished.compactMap { b in overallRating(b).map { (b, $0) } }
        let rated = stableSorted(ratedUnsorted) { $0.item.startDate < $1.item.startDate }

        let vsBrine = rated.compactMap { r in computeBrinePercent(salt: r.item.saltGrams, water: r.item.waterMl).map { XYPoint(x: $0, y: r.rating, name: r.item.name) } }
        let vsTemp = rated.compactMap { r in r.item.roomTempC.map { XYPoint(x: $0, y: r.rating, name: r.item.name) } }
        let vsDays = rated.compactMap { r in fermentDays(r.item, now: now).map { XYPoint(x: Double($0), y: r.rating, name: r.item.name) } }
        let overTime = rated.enumerated().map { XYPoint(x: Double($0.offset + 1), y: $0.element.rating, name: $0.element.item.name) }

        var best: Batch?; var bestRating = -Double.infinity
        for r in rated where r.rating > bestRating { bestRating = r.rating; best = r.item }
        let ratings = rated.map(\.rating)

        return BatchStats(
            vegetables: vegetables, total: list.count,
            active: list.filter { batchStatus($0) != .done }.count,
            finished: finished.count, successRate: successRate,
            avgRating: ratings.isEmpty ? nil : round1(ratings.reduce(0, +) / Double(ratings.count)),
            ratingVsBrine: vsBrine, ratingVsTemp: vsTemp, ratingVsDays: vsDays, ratingOverTime: overTime,
            byVegetable: avgBy(rated) { $0.vegetable }, byForm: avgBy(rated) { $0.form }, byLid: avgBy(rated) { $0.lidType },
            problems: countProblems(finished.map { $0.outcome?.problems ?? [] }),
            bestBatch: best, bestRating: best == nil ? nil : round1(bestRating))
    }

    static func overallBakeRating(_ bk: Bake) -> Double? {
        if let v = bk.ratings.overall { return Double(v) }
        let parts = [bk.ratings.crust, bk.ratings.crumb, bk.ratings.flavour].compactMap { $0 }.map(Double.init)
        return parts.isEmpty ? nil : parts.reduce(0, +) / Double(parts.count)
    }

    static func summarizeBakes(_ bakes: [Bake]) -> BakeStats {
        let ratedUnsorted: [(item: Bake, rating: Double)] = bakes.compactMap { b in overallBakeRating(b).map { (b, $0) } }
        let rated = stableSorted(ratedUnsorted) { $0.item.bakeDate < $1.item.bakeDate }
        var best: Bake?; var bestRating = -Double.infinity
        for r in rated where r.rating > bestRating { bestRating = r.rating; best = r.item }
        let ratings = rated.map(\.rating)
        return BakeStats(
            total: bakes.count, rated: rated.count,
            avgOverall: ratings.isEmpty ? nil : round1(ratings.reduce(0, +) / Double(ratings.count)),
            byRecipe: avgBy(rated) { $0.recipeTitle }, byCategory: avgBy(rated) { $0.category },
            problems: countProblems(bakes.map(\.problems)),
            ratingOverTime: rated.enumerated().map { XYPoint(x: Double($0.offset + 1), y: $0.element.rating, name: $0.element.item.name) },
            bestBake: best, bestRating: best == nil ? nil : round1(bestRating))
    }

    // MARK: Search (AND of terms; steps and plan titles included)

    static func batchSearchText(_ b: Batch) -> String {
        ([b.name, b.vegetable, b.form, b.vesselType, b.lidType, b.weightType, b.notes] + b.additions
            + b.checkIns.map(\.tasteNote) + b.steps.map(\.text) + b.plan.map(\.title)).map { $0.lowercased() }.joined(separator: " ")
    }
    static func bakeSearchText(_ k: Bake) -> String {
        ([k.name, k.category, k.recipeTitle, k.notes] + k.problems).map { $0.lowercased() }.joined(separator: " ")
    }
    static func recipeSearchText(_ r: Recipe) -> String {
        ([r.title, r.category, r.description, r.storage] + r.ingredients + r.equipment + r.steps.flatMap { [$0.title, $0.detail] })
            .map { $0.lowercased() }.joined(separator: " ")
    }

    static func searchAll(_ query: String, batches: [Batch] = [], bakes: [Bake] = [], recipes: [Recipe] = []) -> SearchResults {
        let terms = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if terms.isEmpty { return SearchResults(batches: [], bakes: [], recipes: []) }
        func match(_ text: String) -> Bool { terms.allSatisfy { text.contains($0) } }
        return SearchResults(batches: batches.filter { match(batchSearchText($0)) },
                             bakes: bakes.filter { match(bakeSearchText($0)) },
                             recipes: recipes.filter { match(recipeSearchText($0)) })
    }

    // MARK: Export text

    private static func numStr(_ d: Double?) -> String {
        guard let d, d.isFinite else { return "" }
        return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d)
    }
    private static func intStr(_ i: Int?) -> String { i.map(String.init) ?? "" }

    private static func csvCell(_ s: String) -> String {
        s.contains("\"") || s.contains(",") || s.contains("\n") ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }

    private static func stepLine(_ i: Int, _ s: RecipeStep) -> String {
        "\(i + 1). \(s.title)\(s.time.isEmpty ? "" : " (\(s.time))")\(s.detail.isEmpty ? "" : ": \(s.detail)")"
    }

    private static func stamp(_ d: Date) -> String { d == .distantPast ? "" : "\(isoDay(d)) \(clock(d))" }

    private static func bakeOverallText(_ b: Bake) -> String {
        guard let o = overallBakeRating(b) else { return "" }
        return o == o.rounded() ? String(Int(o)) : String(format: "%.1f", o)
    }

    private static let batchCSVColumns: [(String, (Batch) -> String)] = [
        ("Name", { $0.name }), ("Vegetable", { $0.vegetable }), ("Form", { $0.form }), ("Start date", { $0.startDate }),
        ("Days fermented", { intStr(fermentDays($0)) }),
        ("Brine %", { computeBrinePercent(salt: $0.saltGrams, water: $0.waterMl).map { String(format: "%.1f", $0) } ?? "" }),
        ("Salt (g)", { numStr($0.saltGrams) }), ("Water (ml)", { numStr($0.waterMl) }), ("Room temp (C)", { numStr($0.roomTempC) }),
        ("Vessel", { $0.vesselType }), ("Weight", { $0.weightType }), ("Lid", { $0.lidType }),
        ("Spices", { $0.additions.joined(separator: "; ") }),
        ("Status", { statusLabel(batchStatus($0)) }),
        ("Success", { $0.outcome?.recorded == true ? ($0.outcome?.success == true ? "yes" : "no") : "" }),
        ("Taste", { intStr($0.outcome?.taste) }), ("Sourness", { intStr($0.outcome?.sourness) }),
        ("Crunch", { intStr($0.outcome?.crunch) }), ("Overall", { intStr($0.outcome?.overall) }),
        ("Problems", { ($0.outcome?.problems ?? []).joined(separator: "; ") }),
        ("Notes", { $0.notes }), ("Logged by", { $0.loggedBy }), ("What I did", { stepsText($0) }),
    ]

    /// One row per jar, for spreadsheets.
    static func toCSV(_ batches: [Batch]) -> String {
        let header = batchCSVColumns.map(\.0).joined(separator: ",")
        let rows = batches.map { b in batchCSVColumns.map { csvCell($0.1(b)) }.joined(separator: ",") }
        return ([header] + rows).joined(separator: "\n")
    }

    /// One CSV with everything (jars, bakes, recipes, lessons) as labelled sections. Removed records are left out.
    static func toFullCSV(_ data: AppData) -> String {
        func section<T>(_ title: String, _ cols: [(String, (T) -> String)], _ items: [T]) -> String {
            let header = cols.map(\.0).joined(separator: ",")
            let rows = items.map { it in cols.map { csvCell($0.1(it)) }.joined(separator: ",") }
            return ([title, header] + (rows.isEmpty ? ["(none yet)"] : rows)).joined(separator: "\n")
        }
        let bakeCols: [(String, (Bake) -> String)] = [
            ("Name", { $0.name }), ("Category", { $0.category }), ("Date", { $0.bakeDate }), ("Recipe", { $0.recipeTitle }),
            ("Crust", { intStr($0.ratings.crust) }), ("Crumb", { intStr($0.ratings.crumb) }), ("Flavour", { intStr($0.ratings.flavour) }),
            ("Overall", { bakeOverallText($0) }), ("Problems", { $0.problems.joined(separator: "; ") }),
            ("Notes", { $0.notes }), ("Logged by", { $0.loggedBy }),
        ]
        let recipeCols: [(String, (Recipe) -> String)] = [
            ("Title", { $0.title }), ("Category", { $0.category }), ("Description", { $0.description }),
            ("Ingredients", { $0.ingredients.joined(separator: "; ") }), ("Equipment", { $0.equipment.joined(separator: "; ") }),
            ("Hands-on time", { $0.activeTime }), ("Total time", { $0.totalTime }),
            ("Steps", { r in r.steps.enumerated().map { stepLine($0.offset, $0.element) }.joined(separator: " | ") }),
            ("Storage", { $0.storage }),
        ]
        let lessonCols: [(String, (Lesson) -> String)] = [
            ("Lesson / improvement", { $0.text }), ("Logged by", { $0.loggedBy }), ("Recipe", { $0.recipeTitle }),
            ("From (batch/bake)", { $0.linkLabel }), ("Added", { stamp($0.createdAt) }),
        ]
        return [
            "# Ferments (batches)\n\(toCSV(data.liveBatches))",
            section("# Bakes", bakeCols, data.liveBakes),
            section("# Recipes", recipeCols, data.liveRecipes),
            section("# Lessons learned & improvements", lessonCols, data.liveLessons),
        ].joined(separator: "\n\n") + "\n"
    }

    /// The spreadsheet tabs (Ferments, Bakes, Recipes, Lessons), same columns as the web app. Removed records are left out.
    static func exportSheets(_ data: AppData) -> [Sheet] {
        func n(_ d: Double?) -> Cell { d.map { .number($0) } ?? .empty }
        func ni(_ i: Int?) -> Cell { i.map { .number(Double($0)) } ?? .empty }
        func stars(_ v: Double?) -> Cell { v == nil ? .text("") : .text(ratingStars(v!.rounded())) }
        let ferments = Sheet(name: "Ferments", columns: [
            ("Name", 22), ("Vegetable", 16), ("Form", 12), ("Start date", 12), ("Days fermented", 10), ("Brine %", 8), ("Salt (g)", 8),
            ("Water (ml)", 10), ("Room temp (\u{00b0}C)", 12), ("Vessel", 16), ("Weight", 16), ("Lid", 20), ("Spices", 22),
            ("Status", 12), ("Success", 9), ("Taste", 7), ("Sourness", 9), ("Crunch", 8), ("Overall", 12),
            ("Problems", 24), ("Notes", 40), ("Logged by", 14), ("What I did", 50),
        ], rows: data.liveBatches.map { b in
            let o = b.outcome
            let brine = computeBrinePercent(salt: b.saltGrams, water: b.waterMl)
            return [.text(b.name), .text(b.vegetable), .text(b.form), .text(b.startDate), ni(fermentDays(b)),
                    brine.map { .number(round1($0)) } ?? .empty, n(b.saltGrams), n(b.waterMl), n(b.roomTempC),
                    .text(b.vesselType), .text(b.weightType), .text(b.lidType), .text(b.additions.joined(separator: "\n")),
                    .text(statusLabel(batchStatus(b))), .text(o?.recorded == true ? (o?.success == true ? "Yes" : "No") : ""),
                    ni(o?.taste), ni(o?.sourness), ni(o?.crunch), stars(o?.overall.map(Double.init)),
                    .text((o?.problems ?? []).joined(separator: "\n")), .text(b.notes), .text(b.loggedBy), .text(stepsText(b))]
        })
        let bakes = Sheet(name: "Bakes", columns: [
            ("Name", 22), ("Category", 12), ("Date", 12), ("Recipe", 20), ("Crust", 7), ("Crumb", 7), ("Flavour", 8),
            ("Overall", 12), ("Problems", 24), ("Notes", 40), ("Logged by", 14),
        ], rows: data.liveBakes.map { b in
            [.text(b.name), .text(b.category), .text(b.bakeDate), .text(b.recipeTitle), ni(b.ratings.crust), ni(b.ratings.crumb),
             ni(b.ratings.flavour), stars(overallBakeRating(b)), .text(b.problems.joined(separator: "\n")), .text(b.notes), .text(b.loggedBy)]
        })
        let recipes = Sheet(name: "Recipes", columns: [
            ("Title", 24), ("Category", 14), ("Description", 40), ("Ingredients", 34), ("Equipment", 28),
            ("Hands-on time", 14), ("Total time", 14), ("Steps", 50), ("Storage", 30),
        ], rows: data.liveRecipes.map { r in
            [.text(r.title), .text(r.category), .text(r.description), .text(r.ingredients.joined(separator: "\n")),
             .text(r.equipment.joined(separator: "\n")), .text(r.activeTime), .text(r.totalTime),
             .text(r.steps.enumerated().map { stepLine($0.offset, $0.element) }.joined(separator: "\n")), .text(r.storage)]
        })
        let lessons = Sheet(name: "Lessons", columns: [
            ("Lesson / improvement", 50), ("Logged by", 14), ("Recipe", 22), ("From (batch/bake)", 22), ("Added", 20),
        ], rows: data.liveLessons.map { l in
            [.text(l.text), .text(l.loggedBy), .text(l.recipeTitle), .text(l.linkLabel), .text(stamp(l.createdAt))]
        })
        return [ferments, bakes, recipes, lessons]
    }

    // MARK: Creating

    static func newBatch(now: Date = Date()) -> Batch {
        var b = Batch()
        b.startDate = isoDay(now); b.createdAt = now; b.modifiedAt = now
        return b
    }

    static func presetFromBatch(_ b: Batch, name: String = "", now: Date = Date()) -> Preset {
        var p = Preset()
        p.name = name; p.vegetable = b.vegetable; p.form = b.form
        p.saltGrams = b.saltGrams; p.waterMl = b.waterMl; p.roomTempC = b.roomTempC; p.jarSizeMl = b.jarSizeMl
        p.additions = b.additions; p.vesselType = b.vesselType; p.weightType = b.weightType; p.lidType = b.lidType
        p.remindEveryDays = b.remindEveryDays; p.modifiedAt = now
        return p
    }

    static func batchFromPreset(_ p: Preset, now: Date = Date()) -> Batch {
        var b = newBatch(now: now)
        if !p.vegetable.isEmpty { b.vegetable = p.vegetable }
        if !p.form.isEmpty { b.form = p.form }
        b.saltGrams = p.saltGrams; b.waterMl = p.waterMl; b.roomTempC = p.roomTempC; b.jarSizeMl = p.jarSizeMl
        if !p.vesselType.isEmpty { b.vesselType = p.vesselType }
        if !p.weightType.isEmpty { b.weightType = p.weightType }
        if !p.lidType.isEmpty { b.lidType = p.lidType }
        b.remindEveryDays = p.remindEveryDays
        b.additions = p.additions
        return b
    }

    /// Same set-up, fresh jar: no steps, check-ins, plan, photos or outcome; name + " (copy)".
    static func duplicateBatch(_ b: Batch, now: Date = Date()) -> Batch {
        var nb = batchFromPreset(presetFromBatch(b, now: now), now: now)
        nb.name = b.name.isEmpty ? "" : "\(b.name) (copy)"
        return nb
    }

    static func newRecipe(now: Date = Date()) -> Recipe {
        var r = Recipe(); r.createdAt = now; r.modifiedAt = now
        return r
    }

    static func duplicateRecipe(_ r: Recipe, now: Date = Date()) -> Recipe {
        var c = r
        c.id = newID("r"); c.title = r.title.isEmpty ? "" : "\(r.title) (copy)"
        c.steps = r.steps.map { RecipeStep(title: $0.title, detail: $0.detail, time: $0.time) }
        c.createdAt = now; c.modifiedAt = now; c.deletedAt = nil
        return c
    }

    static func sampleSourdoughRecipe(now: Date = Date()) -> Recipe {
        var r = newRecipe(now: now)
        r.title = "Everyday Sourdough Loaf"
        r.category = "Sourdough"
        r.description = "A simple naturally-leavened loaf with an open crumb and a crisp, deep-brown crust. Mostly waiting \u{2014} very little hands-on work."
        r.ingredients = [
            "100 g active sourdough starter (bubbly, doubled)", "350 g water, room temperature", "500 g bread flour",
            "10 g fine sea salt", "25 g water (to dissolve the salt)",
        ]
        r.equipment = ["Kitchen scale", "Large mixing bowl", "Banneton / proofing basket", "Dutch oven (or a baking stone + lid)", "Lame or a sharp knife for scoring"]
        r.activeTime = "~45 minutes hands-on"
        r.totalTime = "~24 hours (mostly hands-off)"
        r.steps = [
            RecipeStep(title: "Feed the starter", detail: "Feed your starter and let it grow until bubbly and roughly doubled.", time: "4\u{2013}6 h (or overnight)"),
            RecipeStep(title: "Autolyse", detail: "Mix the flour and 350 g water until no dry bits remain. Cover and rest to hydrate.", time: "1 h"),
            RecipeStep(title: "Mix", detail: "Add the starter and the salt dissolved in 25 g water. Squeeze and fold until smooth.", time: "15 min"),
            RecipeStep(title: "Bulk fermentation", detail: "Stretch and fold every 30 min for the first 2 h, then let it rise until puffy and ~50% larger.", time: "4\u{2013}6 h at ~22\u{00b0}C"),
            RecipeStep(title: "Shape", detail: "Pre-shape into a round, bench-rest, then shape tightly and place seam-up in a floured banneton.", time: "30 min"),
            RecipeStep(title: "Cold proof", detail: "Cover and refrigerate overnight to develop flavour and firm up for scoring.", time: "12\u{2013}16 h"),
            RecipeStep(title: "Bake", detail: "Preheat the Dutch oven to 230\u{00b0}C. Turn out the loaf, score, bake covered, then uncovered to brown.", time: "20 min covered + 25 min uncovered"),
        ]
        r.storage = "Cool completely (at least 1 h) before slicing \u{2014} the crumb sets as it cools. Keep cut-side down on a board at room temperature for 2\u{2013}3 days, or slice and freeze for up to 3 months. Refresh slices straight from the freezer in a toaster."
        return r
    }

    static func newBake(now: Date = Date()) -> Bake {
        var b = Bake(); b.bakeDate = isoDay(now); b.createdAt = now; b.modifiedAt = now
        return b
    }

    /// A copy with a fresh id, today's date and a "(copy)" name.
    static func duplicateBake(_ k: Bake, now: Date = Date()) -> Bake {
        var b = k
        b.id = newID("k"); b.name = k.name.isEmpty ? "" : "\(k.name) (copy)"
        b.bakeDate = isoDay(now); b.createdAt = now; b.modifiedAt = now; b.deletedAt = nil
        return b
    }

    // MARK: NEW 1 - Burp alarm

    /// On while the jar is fermenting and the alarm is on: his own choice for this jar, else on for a plain lid.
    static func burpAlarmOn(_ b: Batch) -> Bool {
        batchStatus(b) == .fermenting && (b.burpAlarm ?? (b.lidType == "Plain lid"))
    }

    private static func burpDates(_ b: Batch) -> [Date] {
        b.steps.filter { $0.kind == "burp" }.compactMap { date(fromDay: $0.date, time: $0.time) }
    }

    static func lastBurp(_ b: Batch) -> Date? { burpDates(b).max() }

    /// Every future morning and evening time over the next `days` days; none when the alarm is off.
    /// A slot is skipped when a burp was already logged within the 3 hours before it.
    static func burpSlots(for b: Batch, settings: AppSettings, from now: Date, days: Int = 7) -> [Date] {
        guard burpAlarmOn(b), days > 0 else { return [] }
        let burps = burpDates(b)
        let end = cal.date(byAdding: .day, value: days, to: now) ?? now.addingTimeInterval(Double(days) * 86400)
        let today = isoDay(now)
        var out: [Date] = []
        for offset in 0...days {
            guard let day = addDays(today, offset) else { continue }
            for t in [settings.burpMorning, settings.burpEvening] {
                guard let slot = date(fromDay: day, time: t), slot > now, slot <= end else { continue }
                if burps.contains(where: { $0 <= slot && slot.timeIntervalSince($0) <= 3 * 3600 }) { continue }
                out.append(slot)
            }
        }
        return out.sorted()
    }

    static func burped(_ b: inout Batch, at: Date) {
        b.steps.append(Step(date: isoDay(at), time: clock(at), text: "Burped the jar", kind: "burp"))
        b.modifiedAt = Date()
    }

    static func burpsToday(_ b: Batch, now: Date) -> Int {
        let day = isoDay(now)
        return b.steps.filter { $0.kind == "burp" && $0.date == day }.count
    }

    // MARK: Recipe steps in order (the Mac's drag and drop)

    /// A step dropped on another step takes that step's place and the others close up.
    /// Dropped on itself, or with a step that is not in the list: nothing changes.
    static func moveStep(_ steps: [RecipeStep], id: String, onto target: String) -> [RecipeStep] {
        guard id != target,
              let from = steps.firstIndex(where: { $0.id == id }),
              let to = steps.firstIndex(where: { $0.id == target }) else { return steps }
        var out = steps
        let step = out.remove(at: from)
        out.insert(step, at: to)
        return out
    }

    // MARK: NEW 2 - Save a jar's steps as a recipe

    private static func plainNumber(_ d: Double) -> String { numStr(d) }

    static func recipe(fromStepsOf b: Batch, now: Date) -> Recipe {
        var r = newRecipe(now: now)
        r.title = b.title
        r.category = "Vegetable ferment"
        r.description = "From the jar started \(b.startDate)."
        var ing: [String] = []
        if !b.vegetable.isEmpty { ing.append(b.form.isEmpty ? b.vegetable : "\(b.vegetable), \(b.form.lowercased())") }
        if let s = b.saltGrams { ing.append("\(plainNumber(s)) g salt") }
        if let w = b.waterMl { ing.append("\(plainNumber(w)) ml water") }
        ing += b.additions.filter { !$0.isEmpty }
        r.ingredients = ing
        r.equipment = [b.vesselType, b.weightType == "None" ? "" : b.weightType, b.lidType].filter { !$0.isEmpty }
        r.steps = timelineEntries(b).filter { $0.kind == .did && !$0.isBurp }.map { RecipeStep(title: $0.text) }
        return r
    }

    // MARK: NEW 3 - A jar started from a recipe gets a tick-off list

    /// What the web's batchDraftFromRecipe does, plus recipeID, recipeTitle and the plan.
    /// `customSpices` = his own spices (settings.customSpices), looked for in the ingredients like the built-in ones.
    static func batch(from r: Recipe, now: Date, customSpices: [String] = []) -> Batch {
        var b = newBatch(now: now)
        b.name = r.title
        let title = r.title.lowercased()
        if let veg = VEGETABLES.first(where: { v in
            let l = v.lowercased()
            return title.contains(l) || title.contains(String(l.split(separator: " ").first ?? ""))
        }) { b.vegetable = veg }
        let ing = r.ingredients.joined(separator: " ").lowercased()
        b.additions = unique((COMMON_SPICES + customSpices).filter { ing.contains($0.lowercased()) })
        b.notes = "From recipe: \(r.title)"
        b.recipeID = r.id
        b.recipeTitle = r.title
        b.plan = r.steps.compactMap { s in
            let title = s.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = s.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty { return detail.isEmpty ? nil : PlanStep(title: detail, detail: "", time: s.time) }
            return PlanStep(title: title, detail: detail, time: s.time)
        }
        return b
    }

    /// Tick a plan step: it becomes done now and adds a "Did" line. Ticking a done step does nothing.
    static func tick(_ planStepID: String, in b: inout Batch, at: Date) {
        guard let i = b.plan.firstIndex(where: { $0.id == planStepID }), b.plan[i].doneAt == nil else { return }
        b.plan[i].doneAt = at
        b.steps.append(Step(date: isoDay(at), time: clock(at), text: b.plan[i].title))
        b.modifiedAt = Date()
    }

    /// Un-tick: clears doneAt and removes the "Did" line the tick added (same text, same day and time).
    static func untick(_ planStepID: String, in b: inout Batch) {
        guard let i = b.plan.firstIndex(where: { $0.id == planStepID }), let at = b.plan[i].doneAt else { return }
        let day = isoDay(at), time = clock(at), text = b.plan[i].title
        b.plan[i].doneAt = nil
        if let j = b.steps.firstIndex(where: { $0.text == text && $0.date == day && $0.time == time && $0.kind.isEmpty }) { b.steps.remove(at: j) }
        b.modifiedAt = Date()
    }

    static func planProgress(_ b: Batch) -> (done: Int, total: Int) {
        (b.plan.filter { $0.doneAt != nil }.count, b.plan.count)
    }
}
