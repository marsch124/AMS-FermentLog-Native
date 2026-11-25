import Foundation

// Reads the web app's backup file (js/db.js exportJSON):
//   { app: "fermentlog", version, exportedAt, batches, presets, recipes, bakes, bakeLessons }
//
// What the web app keeps OUTSIDE its backup (browser localStorage, NOT in the export): the people list and the
// active person, his own vegetables / cuts (forms) / spices, theme, backup reminders. So the import derives them:
// custom vegetables, forms and spices from the imported jars and presets, people from every `loggedBy`.
// They are returned in data.settings (merged by WebImport.merge as a union with the current settings).
//
// Every imported record keeps its web id (importing the same backup twice never duplicates) and gets
// modifiedAt = its createdAt (or distantPast + 1 s), so anything already edited natively wins a merge.
// Photos are data URLs in the web app; each is decoded to a file "<uuid>.jpg" (the uuid is made from the picture's
// bytes, so the same picture always gets the same name and a second import adds no new files).

enum WebImport {

    enum Problem: Error, LocalizedError, Equatable {
        case notAFermentLogBackup
        case unreadable
        var errorDescription: String? {
            switch self {
            case .notAFermentLogBackup: return "This file is not a FermentLog backup."
            case .unreadable: return "This file could not be read."
            }
        }
    }

    struct Result {
        var data: AppData
        /// File name -> picture bytes, for the Photos folder.
        var photos: [String: Data]
        var counts: (jars: Int, bakes: Int, recipes: Int, lessons: Int, presets: Int, photos: Int)
    }

    static func read(_ data: Data) throws -> Result {
        guard let root = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { throw Problem.unreadable }
        let batchesIn: [Any]; var presetsIn: [Any] = [], recipesIn: [Any] = [], bakesIn: [Any] = [], lessonsIn: [Any] = []
        if let arr = root as? [Any] {
            batchesIn = arr   // the oldest backups were a bare list of jars
        } else if let obj = root as? [String: Any] {
            guard (obj["app"] as? String) == "fermentlog" else { throw Problem.notAFermentLogBackup }
            batchesIn = obj["batches"] as? [Any] ?? []
            presetsIn = obj["presets"] as? [Any] ?? []
            recipesIn = obj["recipes"] as? [Any] ?? []
            bakesIn = obj["bakes"] as? [Any] ?? []
            lessonsIn = obj["bakeLessons"] as? [Any] ?? []
        } else { throw Problem.notAFermentLogBackup }

        let ctx = Context()
        var out = AppData()
        out.batches = batchesIn.compactMap { ($0 as? [String: Any]).map { ctx.batch($0) } }
        out.presets = presetsIn.compactMap { ($0 as? [String: Any]).map { ctx.preset($0) } }
        out.recipes = recipesIn.compactMap { ($0 as? [String: Any]).map { ctx.recipe($0) } }
        out.bakes = bakesIn.compactMap { ($0 as? [String: Any]).map { ctx.bake($0) } }
        out.lessons = lessonsIn.compactMap { ($0 as? [String: Any]).map { ctx.lesson($0) } }

        // Things the web app kept in localStorage: derive them.
        var s = AppSettings()
        let all = out.batches
        let presetsAsJars: [Batch] = out.presets.map { p in var b = Batch(); b.vegetable = p.vegetable; b.form = p.form; b.additions = p.additions; return b }
        let jars = all + presetsAsJars
        s.customVegetables = Logic.usedVegetables(jars)
        s.customSpices = Logic.usedSpices(jars)
        let builtinForms = Set(Logic.FORMS)
        s.customForms = Set(jars.map(\.form).filter { !$0.isEmpty && !builtinForms.contains($0) }).sorted()
        s.people = unique(out.batches.map(\.loggedBy) + out.bakes.map(\.loggedBy) + out.lessons.map(\.loggedBy))
        s.modifiedAt = Date.distantPast.addingTimeInterval(1)
        out.settings = s

        return Result(data: out, photos: ctx.photos,
                      counts: (out.batches.count, out.bakes.count, out.recipes.count, out.lessons.count, out.presets.count, ctx.photos.count))
    }

    /// Imported records join what is already there; the newest change per record wins, so native edits survive.
    /// Lists in the settings (people, own vegetables, cuts, spices) are joined, never replaced.
    static func merge(_ imported: AppData, into current: AppData) -> AppData {
        var m = AppData.merged(current, imported)
        m.settings.people = unique(current.settings.people + imported.settings.people)
        m.settings.customVegetables = unique(current.settings.customVegetables + imported.settings.customVegetables)
        m.settings.customForms = unique(current.settings.customForms + imported.settings.customForms)
        m.settings.customSpices = unique(current.settings.customSpices + imported.settings.customSpices)
        return m
    }

    private static func unique(_ list: [String]) -> [String] {
        var seen = Set<String>(); var out: [String] = []
        for s in list where !s.isEmpty && !seen.contains(s) { seen.insert(s); out.append(s) }
        return out
    }

    // MARK: - Reading one record

    private final class Context {
        var photos: [String: Data] = [:]
        let fracFormatter: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
        let plainFormatter = ISO8601DateFormatter()
        static let unknown = Date.distantPast.addingTimeInterval(1)

        // -- tolerant readers --
        func str(_ v: Any?) -> String {
            if let s = v as? String { return s }
            if let n = v as? NSNumber, !(v is Bool) { return n.stringValue }
            return ""
        }
        func num(_ v: Any?) -> Double? {
            if let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { let d = n.doubleValue; return d.isFinite ? d : nil }
            if let s = v as? String {
                let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
                if t.isEmpty { return nil }
                if let d = Double(t), d.isFinite { return d }
            }
            return nil
        }
        func int(_ v: Any?) -> Int? { num(v).map { Int($0.rounded()) } }
        func bool(_ v: Any?) -> Bool {
            if let b = v as? Bool { return b }
            if let n = v as? NSNumber { return n.intValue != 0 }
            if let s = v as? String { return ["true", "yes", "1"].contains(s.lowercased()) }
            return false
        }
        func strings(_ v: Any?) -> [String] { (v as? [Any] ?? []).compactMap { $0 as? String }.filter { !$0.isEmpty } }
        func date(_ v: Any?) -> Date? {
            guard let s = v as? String, !s.isEmpty else { return nil }
            return fracFormatter.date(from: s) ?? plainFormatter.date(from: s)
        }
        func day(_ v: Any?) -> String { String(str(v).prefix(10)) }

        func id(_ d: [String: Any], _ prefix: String) -> String {
            let s = str(d["id"]); return s.isEmpty ? newID(prefix) : s
        }

        /// Data URLs become files; returns the file names.
        func importPhotos(_ v: Any?) -> [String] {
            var names: [String] = []
            for item in v as? [Any] ?? [] {
                guard let s = item as? String, s.hasPrefix("data:"), let comma = s.firstIndex(of: ",") else { continue }
                let header = s[s.startIndex..<comma]
                guard header.contains(";base64"), let bytes = Data(base64Encoded: String(s[s.index(after: comma)...]), options: .ignoreUnknownCharacters), !bytes.isEmpty else { continue }
                let name = WebImport.uuidString(from: bytes) + ".jpg"
                photos[name] = bytes
                if !names.contains(name) { names.append(name) }
            }
            return names
        }

        // -- records --
        func batch(_ d: [String: Any]) -> Batch {
            var b = Batch()
            b.id = id(d, "b")
            b.name = str(d["name"]); b.vegetable = str(d["vegetable"]); b.form = str(d["form"])
            b.startDate = day(d["startDate"])
            b.saltGrams = num(d["saltGrams"]); b.waterMl = num(d["waterMl"]); b.roomTempC = num(d["roomTempC"]); b.jarSizeMl = num(d["jarSizeMl"])
            b.additions = strings(d["additions"])
            b.vesselType = str(d["vesselType"]); b.weightType = str(d["weightType"]); b.lidType = str(d["lidType"])
            b.remindEveryDays = int(d["remindEveryDays"]) ?? Logic.DEFAULT_REMIND_DAYS
            b.checkIns = (d["checkIns"] as? [Any] ?? []).enumerated().compactMap { i, x in
                guard let c = x as? [String: Any] else { return nil }
                var ci = CheckIn(date: day(c["date"]), time: str(c["time"]), tasteNote: str(c["tasteNote"]))
                ci.id = str(c["id"]).isEmpty ? "\(b.id)-c\(i)" : str(c["id"])
                return ci
            }
            b.steps = (d["steps"] as? [Any] ?? []).enumerated().compactMap { i, x in
                guard let s = x as? [String: Any] else { return nil }
                var st = Step(date: day(s["date"]), time: str(s["time"]), text: str(s["text"]), kind: str(s["kind"]))
                st.id = str(s["id"]).isEmpty ? "\(b.id)-s\(i)" : str(s["id"])
                return st
            }
            b.movedToFridgeDate = day(d["movedToFridgeDate"])
            if let o = d["outcome"] as? [String: Any] {
                var out = Outcome()
                out.recorded = bool(o["recorded"]); out.success = bool(o["success"])
                out.taste = int(o["taste"]); out.sourness = int(o["sourness"]); out.crunch = int(o["crunch"]); out.overall = int(o["overall"])
                out.problems = strings(o["problems"]); out.recordedAt = date(o["recordedAt"])
                b.outcome = out
            }
            b.photos = importPhotos(d["photos"])
            b.notes = str(d["notes"]); b.loggedBy = str(d["loggedBy"])
            let created = date(d["createdAt"])
            b.createdAt = created ?? Context.unknown; b.modifiedAt = created ?? Context.unknown
            return b
        }

        func preset(_ d: [String: Any]) -> Preset {
            var p = Preset()
            p.id = id(d, "p")
            p.name = str(d["name"]); p.vegetable = str(d["vegetable"]); p.form = str(d["form"])
            p.saltGrams = num(d["saltGrams"]); p.waterMl = num(d["waterMl"]); p.roomTempC = num(d["roomTempC"]); p.jarSizeMl = num(d["jarSizeMl"])
            p.additions = strings(d["additions"])
            p.vesselType = str(d["vesselType"]); p.weightType = str(d["weightType"]); p.lidType = str(d["lidType"])
            p.remindEveryDays = int(d["remindEveryDays"]) ?? Logic.DEFAULT_REMIND_DAYS
            p.modifiedAt = date(d["createdAt"]) ?? Context.unknown
            return p
        }

        func recipe(_ d: [String: Any]) -> Recipe {
            var r = Recipe()
            r.id = id(d, "r")
            r.title = str(d["title"]); r.category = str(d["category"]).isEmpty ? "Other" : str(d["category"]); r.description = str(d["description"])
            r.photos = importPhotos(d["photos"])
            r.ingredients = strings(d["ingredients"]); r.equipment = strings(d["equipment"])
            r.activeTime = str(d["activeTime"]); r.totalTime = str(d["totalTime"]); r.storage = str(d["storage"])
            r.steps = (d["steps"] as? [Any] ?? []).compactMap { x in
                guard let s = x as? [String: Any] else { return nil }
                return RecipeStep(title: str(s["title"]), detail: str(s["detail"]), time: str(s["time"]))
            }
            let created = date(d["createdAt"])
            r.createdAt = created ?? Context.unknown; r.modifiedAt = created ?? Context.unknown
            return r
        }

        func bake(_ d: [String: Any]) -> Bake {
            var k = Bake()
            k.id = id(d, "k")
            k.name = str(d["name"]); k.category = str(d["category"]).isEmpty ? "Other" : str(d["category"]); k.bakeDate = day(d["bakeDate"])
            k.recipeID = str(d["recipeId"]); k.recipeTitle = str(d["recipeTitle"])
            k.photos = importPhotos(d["photos"])
            if let r = d["ratings"] as? [String: Any] {
                k.ratings.crust = int(r["crust"]); k.ratings.crumb = int(r["crumb"]); k.ratings.flavour = int(r["flavour"]); k.ratings.overall = int(r["overall"])
            }
            k.problems = strings(d["problems"]); k.notes = str(d["notes"]); k.loggedBy = str(d["loggedBy"])
            let created = date(d["createdAt"])
            k.createdAt = created ?? Context.unknown; k.modifiedAt = created ?? Context.unknown
            return k
        }

        func lesson(_ d: [String: Any]) -> Lesson {
            var l = Lesson()
            l.id = id(d, "l")
            l.text = str(d["text"]); l.loggedBy = str(d["loggedBy"])
            l.recipeID = str(d["recipeId"]); l.recipeTitle = str(d["recipeTitle"])
            l.linkType = str(d["linkKind"]); l.linkID = str(d["linkId"]); l.linkLabel = str(d["linkLabel"])
            let created = date(d["createdAt"])
            l.createdAt = created ?? Context.unknown; l.modifiedAt = created ?? Context.unknown
            return l
        }
    }

    /// A UUID-shaped name made from the bytes (two FNV-1a runs), so the same picture always gets the same name.
    fileprivate static func uuidString(from data: Data) -> String {
        func fnv(_ seed: UInt64) -> UInt64 {
            var h = seed
            for b in data { h ^= UInt64(b); h = h &* 0x100000001b3 }
            return h
        }
        let a = fnv(0xcbf29ce484222325), b = fnv(0x84222325cbf29ce4 ^ UInt64(data.count))
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 { bytes[i] = UInt8((a >> (UInt64(i) * 8)) & 0xff); bytes[8 + i] = UInt8((b >> (UInt64(i) * 8)) & 0xff) }
        bytes[6] = (bytes[6] & 0x0f) | 0x40; bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])).uuidString
    }
}
