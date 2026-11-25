import SwiftUI

extension Lesson {
    /// A new lesson with the recipe and origin names filled in, so it still reads well if they are removed later.
    static func make(text: String, loggedBy: String, recipe: Recipe?, recipeID: String = "", recipeTitle: String = "", linkType: String = "", linkID: String = "", linkLabel: String = "") -> Lesson {
        var l = Lesson()
        l.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        l.loggedBy = loggedBy
        l.recipeID = recipe?.id ?? recipeID; l.recipeTitle = recipe?.title ?? recipeTitle
        l.linkType = linkType; l.linkID = linkID; l.linkLabel = linkLabel
        return l
    }
}

/// The lessons tied to one bake, and a small field to add another.
struct BakeLessonsOfBake: View {
    @EnvironmentObject var store: Store
    let bake: Bake
    @State private var text = ""

    private var lessons: [Lesson] {
        store.data.liveLessons.filter { $0.linkType == "bake" && $0.linkID == bake.id }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Block(title: "Lessons from this bake", area: .bakes) {
            if lessons.isEmpty { Text("No lessons yet.").font(.subheadline).foregroundStyle(Theme.muted) }
            ForEach(lessons) { l in
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.text)
                    Text([l.loggedBy, Human.day(Logic.isoDay(l.createdAt))].filter { !$0.isEmpty }.joined(separator: " \u{00b7} "))
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .accessibilityIdentifier("bake-lesson-\(l.id)")
            }
            TextField("Add a lesson from this bake", text: $text, axis: .vertical)
                .fieldBox()
                .accessibilityIdentifier("bake-lesson-text")
            Button("Add lesson") { add() }
                .buttonStyle(PrimaryButtonStyle(area: .bakes))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("bake-lesson-add")
        }
    }

    private func add() {
        let recipe = store.data.recipe(bake.recipeID)
        let who = store.data.settings.activePerson.isEmpty ? bake.loggedBy : store.data.settings.activePerson
        store.save(Lesson.make(text: text, loggedBy: who, recipe: recipe, recipeID: bake.recipeID, recipeTitle: bake.recipeTitle, linkType: "bake", linkID: bake.id,
                               linkLabel: bake.name.isEmpty ? bake.category : bake.name))
        text = ""
    }
}
