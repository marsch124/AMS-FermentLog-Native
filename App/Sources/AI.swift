import Foundation

// The optional AI helper (his own key). The prompts, schemas and tolerant parsing follow the web app's js/ai.js.
// Parsing and normalising are pure static functions (tested); only `call` touches the network.
enum AI {
    struct Problem: LocalizedError { let text: String; var errorDescription: String? { text } }

    /// The one place to change the model.
    static let model = "claude-opus-5-5"
    static let keychainService = "com.schabbauer.AMSFermentLog.ai"

    /// The key lives in the Keychain of this device (never in the synced file).
    static var hasKey: Bool { !key.isEmpty }
    static var key: String {
        get { Keychain.read(service: keychainService) }
        set { Keychain.write(newValue.trimmingCharacters(in: .whitespacesAndNewlines), service: keychainService) }
    }

    // MARK: Public calls

    static func buildRecipe(from text: String) async throws -> Recipe {
        normalizeRecipe(try await call(recipeSystem, recipeSchema, "Build a recipe from this description:\n\n\(text)"))
    }

    static func improveRecipe(_ recipe: Recipe, request: String) async throws -> Recipe {
        let system = recipeSystem + "\nYou are improving an EXISTING recipe the user already has. Keep their intent, quantities and identity. Fill obvious gaps (missing per-step times, a short description, storage notes), tidy the wording and step order, and make the instructions clear. Do not invent unusual ingredients or change what the dish is. Return the full improved recipe."
        let current: [String: Any] = [
            "title": recipe.title, "category": recipe.category, "description": recipe.description,
            "ingredients": recipe.ingredients, "equipment": recipe.equipment, "activeTime": recipe.activeTime, "totalTime": recipe.totalTime,
            "steps": recipe.steps.map { ["title": $0.title, "detail": $0.detail, "time": $0.time] }, "storage": recipe.storage,
        ]
        let ask = request.trimmingCharacters(in: .whitespacesAndNewlines)
        let extra = ask.isEmpty ? "" : "\n\nWhat the user would like changed: \(ask)"
        var r = normalizeRecipe(try await call(system, recipeSchema, "Improve and expand this recipe. Return the full recipe as structured data:\n\n\(json(current))\(extra)"))
        r.id = recipe.id; r.photos = recipe.photos; r.createdAt = recipe.createdAt
        return r
    }

    static func buildBatch(from text: String) async throws -> Batch {
        normalizeBatch(try await call(batchSystem, batchSchema, "Build a fermentation batch from this description:\n\n\(text)"))
    }

    static func buildCheckIn(from text: String, startDate: String) async throws -> CheckIn {
        let today = Logic.isoDay(Date())
        let system = """
        You convert a home fermenter's spoken taste-test note into a dated timeline entry.
        Context: the batch started on \(startDate.isEmpty ? "an unknown date" : startDate); today is \(today).
        Rules:
        - date must be in YYYY-MM-DD form. "day 1" is the start date; "day N" is (N-1) days after the start date. "today" = \(today); "yesterday" = the day before today. If an explicit date is stated, use it. If unclear, use today (\(today)).
        - tasteNote: the tasting observation as a short, tidy phrase (e.g. "Tangy and still crunchy").
        Never ask questions.
        """
        return normalizeCheckIn(try await call(system, checkInSchema, "Convert this taste-test note:\n\n\(text)"))
    }

    static func batchTips(_ batch: Batch) async throws -> String {
        let system = "You are a friendly fermentation assistant. Given a vegetable-ferment batch's setup as JSON, write 2 to 4 short, practical tips as ONE plain-text notes string (no markdown, no headings; separate tips with line breaks). Base them on the brine strength, temperature, vegetable and equipment. Be specific and encouraging. Do not make safety or medical guarantees. Never ask questions."
        var info: [String: Any] = ["vegetable": batch.vegetable, "additions": batch.additions, "lidType": batch.lidType, "weightType": batch.weightType]
        if let p = Logic.computeBrinePercent(salt: batch.saltGrams, water: batch.waterMl), p > 0 { info["brinePercent"] = (p * 10).rounded() / 10 }
        if let t = batch.roomTempC { info["roomTempC"] = t }
        if let j = batch.jarSizeMl { info["jarSizeMl"] = j }
        let schema = objectSchema(["notes": ["type": "string"]], required: ["notes"])
        let out = try await call(system, schema, "Give tips for this batch:\n\n\(json(info))")
        return ((out as? [String: Any])?["notes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func buildBake(from text: String, recipes: [Recipe]) async throws -> Bake {
        let today = Logic.isoDay(Date())
        let system = """
        You turn a home baker's freeform description of a bake into structured fields.
        Today is \(today).
        Rules:
        - name: a short label (e.g. "Everyday sourdough"). category must be exactly one of: \(Logic.BAKE_CATEGORIES.joined(separator: ", ")).
        - bakeDate in YYYY-MM-DD. "today" = \(today); "yesterday" = the day before. If a date is stated use it; otherwise use today.
        - crust, crumb, flavour, overall are 1\u{2013}5 integer ratings inferred from how the baker describes them (e.g. "great crust" \u{2248} 5, "a bit dense crumb" \u{2248} 2). Use null for any not mentioned.
        - problems: choose from \(Logic.BAKE_PROBLEMS.joined(separator: ", ")) where they fit; short custom phrases are allowed if clearly stated. [] if none.
        - notes: anything else worth keeping, else "".
        Never ask questions.
        """
        var b = normalizeBake(try await call(system, bakeSchema, "Build a bake from this description:\n\n\(text)"))
        // Link to a recipe when the bake's name is its title.
        let n = b.name.lowercased()
        if !n.isEmpty, let r = recipes.first(where: { !$0.title.isEmpty && $0.title.lowercased() == n }) { b.recipeID = r.id; b.recipeTitle = r.title }
        return b
    }

    // MARK: Prompts and schemas

    private static let recipeSystem = """
    You turn a home cook's freeform description of a fermentation or baking recipe into a structured recipe.
    Rules:
    - Keep the user's own quantities, temperatures and times exactly as given. Do not invent ingredients or steps that aren't implied.
    - category must be exactly one of: \(Logic.RECIPE_CATEGORIES.joined(separator: ", ")). Pick the best fit; use "Other" if unsure.
    - Break the method into clear, ordered steps. Each step has a short title, an optional detail, and a time string (e.g. "4-6 h", "overnight", "20 min") when one is given; use "" when no time was mentioned.
    - ingredients and equipment are arrays of short strings, one item each.
    - activeTime is hands-on time; totalTime is start to finish. Use "" if not stated.
    - storage: any notes about keeping or storing the result, else "".
    - If the description is sparse, fill what you can and leave the rest as empty strings or arrays. Never ask questions.
    """

    private static let batchSystem = """
    You turn a home fermenter's freeform description of a new jar/batch into structured fields.
    Rules:
    - Keep the user's own numbers. saltGrams is grams of salt; waterMl is millilitres of water.
    - If the user gives a brine percentage, compute saltGrams to match, where brine% = salt / (salt + water) * 100. If a water amount is given use it; otherwise assume 1000 ml water. So saltGrams = round( (brine/100) * water / (1 - brine/100) ). Set waterMl to the water used.
    - roomTempC is room temperature in Celsius; jarSizeMl is the jar volume in millilitres.
    - additions: spices / flavourings mentioned (garlic, dill, chilli, \u{2026}) as short strings.
    - vesselType is free text (e.g. "Glass jar").
    - lidType must be exactly one of: \(Logic.LID_TYPES.joined(separator: " | ")) \u{2014} map the user's words to the closest one; use "" if none fits.
    - weightType must be exactly one of: \(Logic.WEIGHT_TYPES.joined(separator: " | ")) \u{2014} map the user's words to the closest one; use "" if none fits.
    - remindEveryDays: number of days between taste-test reminders if stated, else null.
    - name: a short label if given, else "".
    - vegetable: just the vegetable being fermented (e.g. "Carrot", "Cucumber", "Cabbage") \u{2014} do NOT include how it's cut; if not stated, "".
    - form: how it's cut or prepared, as a single word if stated (e.g. Sticks, Slices, Rounds, Cubes, Spears, Shredded, Grated, Whole, Halved), else "".
    - Use null for any number not stated, and "" or [] for missing text/lists. Never ask questions.
    """

    private static let str: [String: Any] = ["type": "string"]
    private static let strList: [String: Any] = ["type": "array", "items": ["type": "string"]]
    private static let numOrNull: [String: Any] = ["anyOf": [["type": "number"], ["type": "null"]]]

    private static func objectSchema(_ props: [String: Any], required: [String]) -> [String: Any] {
        ["type": "object", "additionalProperties": false, "properties": props, "required": required]
    }

    private static let recipeSchema: [String: Any] = objectSchema([
        "title": str, "category": ["type": "string", "enum": Logic.RECIPE_CATEGORIES], "description": str,
        "ingredients": strList, "equipment": strList, "activeTime": str, "totalTime": str,
        "steps": ["type": "array", "items": objectSchema(["title": str, "detail": str, "time": str], required: ["title", "detail", "time"])],
        "storage": str,
    ], required: ["title", "category", "description", "ingredients", "equipment", "activeTime", "totalTime", "steps", "storage"])

    private static let batchSchema: [String: Any] = objectSchema([
        "name": str, "vegetable": str, "form": str, "saltGrams": numOrNull, "waterMl": numOrNull, "roomTempC": numOrNull, "jarSizeMl": numOrNull,
        "additions": strList, "vesselType": str, "lidType": str, "weightType": str, "remindEveryDays": numOrNull,
    ], required: ["name", "vegetable", "form", "saltGrams", "waterMl", "roomTempC", "jarSizeMl", "additions", "vesselType", "lidType", "weightType", "remindEveryDays"])

    private static let checkInSchema: [String: Any] = objectSchema(["date": str, "tasteNote": str], required: ["date", "tasteNote"])

    private static let bakeSchema: [String: Any] = objectSchema([
        "name": str, "category": ["type": "string", "enum": Logic.BAKE_CATEGORIES], "bakeDate": str,
        "crust": numOrNull, "crumb": numOrNull, "flavour": numOrNull, "overall": numOrNull, "problems": strList, "notes": str,
    ], required: ["name", "category", "bakeDate", "crust", "crumb", "flavour", "overall", "problems", "notes"])

    // MARK: Network

    /// The request, built without sending it (so a test can look at it).
    static func makeRequest(system: String, schema: [String: Any], user: String, key: String) throws -> URLRequest {
        let body: [String: Any] = [
            "model": model, "max_tokens": 4096, "system": system,
            "output_config": ["format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": user]],
        ]
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private static func call(_ system: String, _ schema: [String: Any], _ user: String) async throws -> Any {
        let k = key
        guard !k.isEmpty else { throw Problem(text: "No key yet. Add one in Settings, under AI assistant.") }
        let req = try makeRequest(system: system, schema: schema, user: user, key: k)
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch let e as URLError where e.code == .timedOut { throw Problem(text: "The AI took too long. Please try again.") }
        catch { throw Problem(text: "Could not reach the AI. Check your internet connection.") }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw Problem(text: errorSentence(status: status, body: data)) }
        return try extractJSON(textOf(data))
    }

    /// A plain sentence for a failed request.
    static func errorSentence(status: Int, body: Data) -> String {
        switch status {
        case 401: return "That key was not accepted."
        case 429: return "The AI is busy right now. Wait a moment and try again."
        default:
            if let o = try? JSONSerialization.jsonObject(with: body) as? [String: Any], let e = o["error"] as? [String: Any],
               let m = e["message"] as? String, !m.isEmpty { return m }
            return "The request failed (\(status))."
        }
    }

    /// The text blocks of a Messages reply, joined.
    static func textOf(_ data: Data) -> String {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let c = o["content"] as? [[String: Any]] else { return "" }
        return c.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
    }

    private static func json(_ o: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }

    // MARK: Tolerant parsing (pure)

    /// Parse the model's JSON, tolerating stray prose or code fences.
    static func extractJSON(_ s: String) throws -> Any {
        func parse(_ t: String) -> Any? { t.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } }
        if let v = parse(s) { return v }
        if let a = s.firstIndex(of: "{"), let b = s.lastIndex(of: "}"), a < b, let v = parse(String(s[a...b])) { return v }
        throw Problem(text: "The AI's answer could not be read. Please try again.")
    }

    // MARK: Normalising (pure)

    private static func text(_ v: Any?) -> String { (v as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    private static func list(_ v: Any?) -> [String] {
        ((v as? [Any]) ?? []).compactMap { $0 as? String }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    private static func number(_ v: Any?) -> Double? {
        guard let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite else { return nil }
        return n.doubleValue
    }
    /// A day in 2026-11-25 form that is a real date; else nil.
    private static func realDay(_ v: Any?) -> String? {
        guard let s = v as? String, s.count == 10, Logic.date(fromDay: s) != nil else { return nil }
        return s
    }

    static func normalizeRecipe(_ ai: Any?, now: Date = Date()) -> Recipe {
        let o = ai as? [String: Any] ?? [:]
        var r = Logic.newRecipe(now: now)
        r.title = text(o["title"])
        let cat = o["category"] as? String ?? ""
        r.category = Logic.RECIPE_CATEGORIES.contains(cat) ? cat : "Other"
        r.description = text(o["description"])
        r.ingredients = list(o["ingredients"]); r.equipment = list(o["equipment"])
        r.activeTime = text(o["activeTime"]); r.totalTime = text(o["totalTime"]); r.storage = text(o["storage"])
        r.steps = ((o["steps"] as? [Any]) ?? []).map { s -> RecipeStep in
            let d = s as? [String: Any] ?? [:]
            return RecipeStep(title: text(d["title"]), detail: text(d["detail"]), time: text(d["time"]))
        }.filter { !($0.title.isEmpty && $0.detail.isEmpty && $0.time.isEmpty) }
        return r
    }

    private static func matchOption(_ value: Any?, _ options: [String]) -> String? {
        let v = text(value).lowercased()
        if v.isEmpty { return nil }
        return options.first { $0.lowercased() == v } ?? options.first { $0.lowercased().contains(v) || v.contains($0.lowercased()) }
    }

    static func normalizeBatch(_ ai: Any?, now: Date = Date()) -> Batch {
        let o = ai as? [String: Any] ?? [:]
        var b = Logic.newBatch(now: now)
        if !text(o["name"]).isEmpty { b.name = text(o["name"]) }
        if !text(o["vegetable"]).isEmpty { b.vegetable = text(o["vegetable"]); b.form = text(o["form"]) }
        else if !text(o["form"]).isEmpty { b.form = text(o["form"]) }
        b.saltGrams = number(o["saltGrams"]) ?? b.saltGrams
        b.waterMl = number(o["waterMl"]) ?? b.waterMl
        b.roomTempC = number(o["roomTempC"]) ?? b.roomTempC
        b.jarSizeMl = number(o["jarSizeMl"]) ?? b.jarSizeMl
        b.additions = list(o["additions"])
        if !text(o["vesselType"]).isEmpty { b.vesselType = text(o["vesselType"]) }
        if let l = matchOption(o["lidType"], Logic.LID_TYPES) { b.lidType = l }
        if let w = matchOption(o["weightType"], Logic.WEIGHT_TYPES) { b.weightType = w }
        if let d = number(o["remindEveryDays"]) { b.remindEveryDays = max(0, Int(d.rounded())) }
        return b
    }

    /// The model's check-in; a bad or missing date becomes today.
    static func normalizeCheckIn(_ ai: Any?, now: Date = Date()) -> CheckIn {
        let o = ai as? [String: Any] ?? [:]
        return CheckIn(date: realDay(o["date"]) ?? Logic.isoDay(now), tasteNote: text(o["tasteNote"]))
    }

    static func normalizeBake(_ ai: Any?, now: Date = Date()) -> Bake {
        let o = ai as? [String: Any] ?? [:]
        func rating(_ v: Any?) -> Int? { number(v).map { max(1, min(5, Int($0.rounded()))) } }
        var b = Logic.newBake(now: now)
        if !text(o["name"]).isEmpty { b.name = text(o["name"]) }
        let cat = o["category"] as? String ?? ""
        b.category = Logic.BAKE_CATEGORIES.contains(cat) ? cat : "Sourdough"
        b.bakeDate = realDay(o["bakeDate"]) ?? Logic.isoDay(now)
        b.ratings.crust = rating(o["crust"]); b.ratings.crumb = rating(o["crumb"]); b.ratings.flavour = rating(o["flavour"]); b.ratings.overall = rating(o["overall"])
        b.problems = list(o["problems"]); b.notes = text(o["notes"])
        return b
    }
}
