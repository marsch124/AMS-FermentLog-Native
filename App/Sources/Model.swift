import Foundation

// Everything FermentLog stores. Every record decodes TOLERANTLY: a missing key gets its default and an
// unknown key is ignored — so a newer version never fails to read an older file, and an older device
// never fails to read a newer one. Day-only dates stay text ("2026-11-25") and clock times stay text
// ("10:30"), exactly as the web app wrote them, so a web backup reads straight in.

extension KeyedDecodingContainer {
    /// The value, or the fallback when the key is missing or unreadable.
    func get<T: Decodable>(_ key: Key, _ fallback: T) -> T { (try? decodeIfPresent(T.self, forKey: key)) ?? fallback }
    func opt<T: Decodable>(_ key: Key) -> T? { try? decodeIfPresent(T.self, forKey: key) }
}

/// A record that can be merged between devices: the newest change wins, removed ones carry a tombstone.
protocol Record: Codable, Identifiable, Equatable where ID: Hashable {
    var modifiedAt: Date { get set }
    var deletedAt: Date? { get set }
}
extension Record { var isRemoved: Bool { deletedAt != nil } }

/// Newest change per record wins; records only one side knows are kept.
func mergeRecords<T: Record>(_ a: [T], _ b: [T]) -> [T] {
    var byID: [T.ID: T] = [:]
    var order: [T.ID] = []
    for r in a { byID[r.id] = r; order.append(r.id) }
    for r in b {
        if let have = byID[r.id] { if r.modifiedAt > have.modifiedAt { byID[r.id] = r } }
        else { byID[r.id] = r; order.append(r.id) }
    }
    return order.compactMap { byID[$0] }
}

func newID(_ prefix: String) -> String { "\(prefix)_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(6).lowercased())" }

// MARK: - A jar (the web app calls it a batch)

/// One line of a jar's Timeline that says what you did ("Did").
struct Step: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var date = ""          // "2026-11-25"
    var time = ""          // "10:30", or "" when unknown
    var text = ""
    /// "burp" when the line came from the Burped button or the alarm's button; "" otherwise.
    var kind = ""
    init(date: String, time: String = "", text: String, kind: String = "") { self.date = date; self.time = time; self.text = text; self.kind = kind }
    enum CodingKeys: String, CodingKey { case id, date, time, text, kind }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.get(.id, UUID().uuidString); date = c.get(.date, ""); time = c.get(.time, ""); text = c.get(.text, ""); kind = c.get(.kind, "")
    }
}

/// One line of a jar's Timeline that is a taste test ("Taste").
struct CheckIn: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var date = ""
    var time = ""
    var tasteNote = ""
    init(date: String, time: String = "", tasteNote: String) { self.date = date; self.time = time; self.tasteNote = tasteNote }
    enum CodingKeys: String, CodingKey { case id, date, time, tasteNote }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.get(.id, UUID().uuidString); date = c.get(.date, ""); time = c.get(.time, ""); tasteNote = c.get(.tasteNote, "")
    }
}

/// One step still to do in a jar that was started from a recipe: tick it and it becomes a "Did" line.
struct PlanStep: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var title = ""
    var detail = ""
    var time = ""          // the recipe's own hint, e.g. "3 min"
    /// When it was ticked; nil = still to do.
    var doneAt: Date?
    init(title: String, detail: String = "", time: String = "") { self.title = title; self.detail = detail; self.time = time }
    enum CodingKeys: String, CodingKey { case id, title, detail, time, doneAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.get(.id, UUID().uuidString); title = c.get(.title, ""); detail = c.get(.detail, ""); time = c.get(.time, ""); doneAt = c.opt(.doneAt)
    }
}

struct Outcome: Codable, Equatable {
    var recorded = false
    var success = false
    var taste: Int?
    var sourness: Int?
    var crunch: Int?
    var overall: Int?
    var problems: [String] = []
    var recordedAt: Date?
    init() {}
    enum CodingKeys: String, CodingKey { case recorded, success, taste, sourness, crunch, overall, problems, recordedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        recorded = c.get(.recorded, false); success = c.get(.success, false)
        taste = c.opt(.taste); sourness = c.opt(.sourness); crunch = c.opt(.crunch); overall = c.opt(.overall)
        problems = c.get(.problems, []); recordedAt = c.opt(.recordedAt)
    }
}

struct Batch: Record {
    var id = newID("b")
    var name = ""
    var vegetable = "Carrot"
    var form = "Sticks"
    var startDate = ""               // "2026-11-25"
    var saltGrams: Double? = 25
    var waterMl: Double? = 1000
    var roomTempC: Double? = 20
    var jarSizeMl: Double? = 1000
    var additions: [String] = []     // the spices
    var vesselType = "Glass jar"
    var weightType = "Glass weight"
    var lidType = "Burping / self-venting lid"
    var remindEveryDays = 3          // taste-test reminder; 0 = off
    var checkIns: [CheckIn] = []
    var steps: [Step] = []
    /// Steps still to do, copied from the recipe this jar was started from.
    var plan: [PlanStep] = []
    var recipeID = ""
    var recipeTitle = ""
    var movedToFridgeDate = ""
    var outcome: Outcome?
    /// Names of picture files in the Photos folder.
    var photos: [String] = []
    var notes = ""
    var loggedBy = ""
    /// nil = by the lid (on for a plain lid, off for the others); true/false = his own choice for this jar.
    var burpAlarm: Bool?
    var createdAt = Date()
    var modifiedAt = Date()
    var deletedAt: Date?
    init() {}
    enum CodingKeys: String, CodingKey { case id, name, vegetable, form, startDate, saltGrams, waterMl, roomTempC, jarSizeMl, additions, vesselType, weightType, lidType, remindEveryDays, checkIns, steps, plan, recipeID, recipeTitle, movedToFridgeDate, outcome, photos, notes, loggedBy, burpAlarm, createdAt, modifiedAt, deletedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.get(.id, newID("b")); name = c.get(.name, ""); vegetable = c.get(.vegetable, ""); form = c.get(.form, "")
        startDate = c.get(.startDate, ""); saltGrams = c.opt(.saltGrams); waterMl = c.opt(.waterMl); roomTempC = c.opt(.roomTempC); jarSizeMl = c.opt(.jarSizeMl)
        additions = c.get(.additions, []); vesselType = c.get(.vesselType, ""); weightType = c.get(.weightType, ""); lidType = c.get(.lidType, "")
        remindEveryDays = c.get(.remindEveryDays, 3); checkIns = c.get(.checkIns, []); steps = c.get(.steps, []); plan = c.get(.plan, [])
        recipeID = c.get(.recipeID, ""); recipeTitle = c.get(.recipeTitle, ""); movedToFridgeDate = c.get(.movedToFridgeDate, "")
        outcome = c.opt(.outcome); photos = c.get(.photos, []); notes = c.get(.notes, ""); loggedBy = c.get(.loggedBy, "")
        burpAlarm = c.opt(.burpAlarm); createdAt = c.get(.createdAt, .distantPast); modifiedAt = c.get(.modifiedAt, .distantPast); deletedAt = c.opt(.deletedAt)
    }
    /// The name a screen shows: the jar's own name, else its vegetable.
    var title: String { name.isEmpty ? vegetable : name }
}

/// A saved set of jar settings to start future jars from ("batch template").
struct Preset: Record {
    var id = newID("p")
    var name = ""
    var vegetable = ""
    var form = ""
    var saltGrams: Double?
    var waterMl: Double?
    var roomTempC: Double?
    var jarSizeMl: Double?
    var additions: [String] = []
    var vesselType = ""
    var weightType = ""
    var lidType = ""
    var remindEveryDays = 3
    var modifiedAt = Date()
    var deletedAt: Date?
    init() {}
    enum CodingKeys: String, CodingKey { case id, name, vegetable, form, saltGrams, waterMl, roomTempC, jarSizeMl, additions, vesselType, weightType, lidType, remindEveryDays, modifiedAt, deletedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.get(.id, newID("p")); name = c.get(.name, ""); vegetable = c.get(.vegetable, ""); form = c.get(.form, "")
        saltGrams = c.opt(.saltGrams); waterMl = c.opt(.waterMl); roomTempC = c.opt(.roomTempC); jarSizeMl = c.opt(.jarSizeMl)
        additions = c.get(.additions, []); vesselType = c.get(.vesselType, ""); weightType = c.get(.weightType, ""); lidType = c.get(.lidType, "")
        remindEveryDays = c.get(.remindEveryDays, 3); modifiedAt = c.get(.modifiedAt, .distantPast); deletedAt = c.opt(.deletedAt)
    }
}

// MARK: - Recipes

struct RecipeStep: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var title = ""
    var detail = ""
    var time = ""
    init(title: String = "", detail: String = "", time: String = "") { self.title = title; self.detail = detail; self.time = time }
    enum CodingKeys: String, CodingKey { case id, title, detail, time }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.get(.id, UUID().uuidString); title = c.get(.title, ""); detail = c.get(.detail, ""); time = c.get(.time, "")
    }
}

struct Recipe: Record {
    var id = newID("r")
    var title = ""
    var category = "Sourdough"
    var description = ""
    var photos: [String] = []
    var ingredients: [String] = []
    var equipment: [String] = []
    var activeTime = ""
    var totalTime = ""
    var steps: [RecipeStep] = []
    var storage = ""
    var createdAt = Date()
    var modifiedAt = Date()
    var deletedAt: Date?
    init() {}
    enum CodingKeys: String, CodingKey { case id, title, category, description, photos, ingredients, equipment, activeTime, totalTime, steps, storage, createdAt, modifiedAt, deletedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.get(.id, newID("r")); title = c.get(.title, ""); category = c.get(.category, "Other"); description = c.get(.description, "")
        photos = c.get(.photos, []); ingredients = c.get(.ingredients, []); equipment = c.get(.equipment, [])
        activeTime = c.get(.activeTime, ""); totalTime = c.get(.totalTime, ""); steps = c.get(.steps, []); storage = c.get(.storage, "")
        createdAt = c.get(.createdAt, .distantPast); modifiedAt = c.get(.modifiedAt, .distantPast); deletedAt = c.opt(.deletedAt)
    }
}

// MARK: - Bakes and lessons

struct BakeRatings: Codable, Equatable {
    var crust: Int?
    var crumb: Int?
    var flavour: Int?
    var overall: Int?
    init() {}
    enum CodingKeys: String, CodingKey { case crust, crumb, flavour, overall }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        crust = c.opt(.crust); crumb = c.opt(.crumb); flavour = c.opt(.flavour); overall = c.opt(.overall)
    }
}

struct Bake: Record {
    var id = newID("k")
    var name = ""
    var category = "Sourdough"
    var bakeDate = ""
    var recipeID = ""
    var recipeTitle = ""
    var photos: [String] = []
    var ratings = BakeRatings()
    var problems: [String] = []
    var notes = ""
    var loggedBy = ""
    var createdAt = Date()
    var modifiedAt = Date()
    var deletedAt: Date?
    init() {}
    enum CodingKeys: String, CodingKey { case id, name, category, bakeDate, recipeID, recipeTitle, photos, ratings, problems, notes, loggedBy, createdAt, modifiedAt, deletedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.get(.id, newID("k")); name = c.get(.name, ""); category = c.get(.category, "Other"); bakeDate = c.get(.bakeDate, "")
        recipeID = c.get(.recipeID, ""); recipeTitle = c.get(.recipeTitle, ""); photos = c.get(.photos, []); ratings = c.get(.ratings, BakeRatings())
        problems = c.get(.problems, []); notes = c.get(.notes, ""); loggedBy = c.get(.loggedBy, "")
        createdAt = c.get(.createdAt, .distantPast); modifiedAt = c.get(.modifiedAt, .distantPast); deletedAt = c.opt(.deletedAt)
    }
}

/// A lesson learned or an improvement to try, optionally tied to a recipe and to the jar or bake it came from.
struct Lesson: Record {
    var id = newID("l")
    var text = ""
    var loggedBy = ""
    var recipeID = ""
    var recipeTitle = ""
    /// "batch" or "bake" when it came from one; "" otherwise.
    var linkType = ""
    var linkID = ""
    var linkLabel = ""
    var createdAt = Date()
    var modifiedAt = Date()
    var deletedAt: Date?
    init() {}
    enum CodingKeys: String, CodingKey { case id, text, loggedBy, recipeID, recipeTitle, linkType, linkID, linkLabel, createdAt, modifiedAt, deletedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.get(.id, newID("l")); text = c.get(.text, ""); loggedBy = c.get(.loggedBy, ""); recipeID = c.get(.recipeID, ""); recipeTitle = c.get(.recipeTitle, "")
        linkType = c.get(.linkType, ""); linkID = c.get(.linkID, ""); linkLabel = c.get(.linkLabel, "")
        createdAt = c.get(.createdAt, .distantPast); modifiedAt = c.get(.modifiedAt, .distantPast); deletedAt = c.opt(.deletedAt)
    }
}

// MARK: - Settings that travel with the data (the same on every device)

struct AppSettings: Codable, Equatable {
    /// Who logs: names, and the one stamped on new entries.
    var people: [String] = []
    var activePerson = ""
    /// His own vegetables, cuts and spices, remembered beside the built-in ones.
    var customVegetables: [String] = []
    var customForms: [String] = []
    var customSpices: [String] = []
    /// The burp alarm's two times of day.
    var burpMorning = "08:00"
    var burpEvening = "20:00"
    /// Days between "time for a backup" reminders; 0 = off.
    var backupCadenceDays = 30
    var lastBackupAt: Date?
    var modifiedAt = Date.distantPast
    init() {}
    enum CodingKeys: String, CodingKey { case people, activePerson, customVegetables, customForms, customSpices, burpMorning, burpEvening, backupCadenceDays, lastBackupAt, modifiedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        people = c.get(.people, []); activePerson = c.get(.activePerson, "")
        customVegetables = c.get(.customVegetables, []); customForms = c.get(.customForms, []); customSpices = c.get(.customSpices, [])
        burpMorning = c.get(.burpMorning, "08:00"); burpEvening = c.get(.burpEvening, "20:00")
        backupCadenceDays = c.get(.backupCadenceDays, 30); lastBackupAt = c.opt(.lastBackupAt); modifiedAt = c.get(.modifiedAt, .distantPast)
    }
}

// MARK: - The whole file

struct AppData: Codable, Equatable {
    var batches: [Batch] = []
    var presets: [Preset] = []
    var recipes: [Recipe] = []
    var bakes: [Bake] = []
    var lessons: [Lesson] = []
    var settings = AppSettings()
    var savedAt = Date.distantPast
    /// Which data format saved this file. 🚨 Raise `currentFormat` by one in EVERY version that adds a stored
    /// field to anything in here: a device still on an older version then says "Update this device first"
    /// and does not write the file — it would save it without the fields it does not know.
    var format = AppData.currentFormat
    static let currentFormat = 1   // 6.0: the first native format
    init() {}
    enum CodingKeys: String, CodingKey { case batches, presets, recipes, bakes, lessons, settings, savedAt, format }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        batches = c.get(.batches, []); presets = c.get(.presets, []); recipes = c.get(.recipes, []); bakes = c.get(.bakes, []); lessons = c.get(.lessons, [])
        settings = c.get(.settings, AppSettings()); savedAt = c.get(.savedAt, .distantPast); format = c.get(.format, 0)
    }

    /// Two copies of the file become one: the newest change per record wins, and nothing one side knows is lost.
    static func merged(_ a: AppData, _ b: AppData) -> AppData {
        var out = a
        out.batches = mergeRecords(a.batches, b.batches)
        out.presets = mergeRecords(a.presets, b.presets)
        out.recipes = mergeRecords(a.recipes, b.recipes)
        out.bakes = mergeRecords(a.bakes, b.bakes)
        out.lessons = mergeRecords(a.lessons, b.lessons)
        out.settings = b.settings.modifiedAt > a.settings.modifiedAt ? b.settings : a.settings
        out.savedAt = max(a.savedAt, b.savedAt)
        out.format = max(a.format, b.format)
        return out
    }

    /// The records a screen shows — removed ones are hidden.
    var liveBatches: [Batch] { batches.filter { !$0.isRemoved } }
    var livePresets: [Preset] { presets.filter { !$0.isRemoved } }
    var liveRecipes: [Recipe] { recipes.filter { !$0.isRemoved } }
    var liveBakes: [Bake] { bakes.filter { !$0.isRemoved } }
    var liveLessons: [Lesson] { lessons.filter { !$0.isRemoved } }
    func batch(_ id: String) -> Batch? { batches.first { $0.id == id && !$0.isRemoved } }
    func recipe(_ id: String) -> Recipe? { recipes.first { $0.id == id && !$0.isRemoved } }
    func bake(_ id: String) -> Bake? { bakes.first { $0.id == id && !$0.isRemoved } }
}

extension JSONDecoder {
    static let app: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
}
extension JSONEncoder {
    static let app: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys, .prettyPrinted]; return e }()
}
