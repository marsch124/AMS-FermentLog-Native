import Foundation

/// Words for a recipe that is shared (the web's recipeSummaryText) and small helpers the recipe screens use.
enum RecipeText {
    static func summary(_ r: Recipe) -> String {
        var l = ["\(r.title) (\(r.category))"]
        if !r.description.isEmpty { l.append(r.description) }
        if !r.activeTime.isEmpty { l.append("Hands-on: \(r.activeTime)") }
        if !r.totalTime.isEmpty { l.append("Total: \(r.totalTime)") }
        if !r.ingredients.isEmpty { l.append("\nIngredients:\n" + r.ingredients.map { "- \($0)" }.joined(separator: "\n")) }
        if !r.equipment.isEmpty { l.append("\nEquipment:\n" + r.equipment.map { "- \($0)" }.joined(separator: "\n")) }
        if !r.steps.isEmpty {
            l.append("\nMethod:\n" + r.steps.enumerated().map { i, s in
                "\(i + 1). \(s.title)\(s.time.isEmpty ? "" : " (\(s.time))")\(s.detail.isEmpty ? "" : " \u{2014} \(s.detail)")"
            }.joined(separator: "\n"))
        }
        if !r.storage.isEmpty { l.append("\nStorage: \(r.storage)") }
        return l.joined(separator: "\n")
    }

    /// Lines of a multi-line editor: trimmed, empty ones dropped.
    static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// A bake started from a recipe (the web's bakeDraftFromRecipe).
    static func bakeDraft(from r: Recipe) -> Bake {
        var b = Logic.newBake()
        b.name = r.title
        b.category = r.category == "Sourdough" ? "Sourdough" : "Other"
        b.recipeID = r.id
        b.recipeTitle = r.title
        return b
    }
}
