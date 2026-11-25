import SwiftUI

/// "Lessons learned and improvements": the notebook, newest first, and the form to add to it.
struct BakeLessonsSection: View {
    @EnvironmentObject var store: Store
    @State private var text = ""
    @State private var by = ""
    @State private var recipeID = ""
    /// "batch:<id>" or "bake:<id>", or "" for none.
    @State private var from = ""

    private var lessons: [Lesson] { store.data.liveLessons.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        Block(title: "Lessons learned and improvements", area: .bakes) {
            Text("Your running notebook: jot what you learn, and say who noticed it and which recipe it is about.")
                .font(.caption).foregroundStyle(Theme.muted)
            if lessons.isEmpty { Text("No lessons yet. Add what you learn as you bake.").font(.subheadline).foregroundStyle(Theme.muted) }
            ForEach(lessons) { l in
                HStack(alignment: .top, spacing: Theme.gap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.text)
                        let meta = [l.loggedBy, l.recipeTitle.isEmpty ? "" : "Recipe: \(l.recipeTitle)",
                                    l.linkLabel.isEmpty ? "" : "From: \(l.linkLabel)", Human.day(Logic.isoDay(l.createdAt))].filter { !$0.isEmpty }
                        Text(meta.joined(separator: " \u{00b7} ")).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    Button("Remove") { remove(l) }
                        .font(.caption).foregroundStyle(Theme.problem).buttonStyle(.plain)
                        .accessibilityIdentifier("lesson-remove-\(l.id)")
                }
                .accessibilityIdentifier("lesson-row-\(l.id)")
            }
            Divider()
            TextField("e.g. A longer cold proof gives a tangier, more open crumb", text: $text, axis: .vertical)
                .fieldBox().accessibilityIdentifier("lesson-text")
            LoggedByPicker(name: $by)
            Picker("Recipe", selection: $recipeID) {
                Text("None").tag("")
                ForEach(store.data.liveRecipes) { Text($0.title.isEmpty ? "Untitled" : $0.title).tag($0.id) }
            }.accessibilityIdentifier("lesson-recipe")
            Picker("From a jar or bake", selection: $from) {
                Text("None").tag("")
                ForEach(store.data.liveBatches) { Text("Jar: \($0.title)").tag("batch:\($0.id)") }
                ForEach(store.data.liveBakes) { Text("Bake: \($0.name.isEmpty ? $0.category : $0.name)").tag("bake:\($0.id)") }
            }.accessibilityIdentifier("lesson-from")
            Button("Add lesson") { add() }
                .buttonStyle(PrimaryButtonStyle(area: .bakes))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("lesson-add")
        }
        .onAppear { if by.isEmpty { by = store.data.settings.activePerson } }
    }

    private func add() {
        var type = "", id = "", label = ""
        if from.hasPrefix("batch:"), let b = store.data.batch(String(from.dropFirst(6))) { type = "batch"; id = b.id; label = b.title }
        if from.hasPrefix("bake:"), let k = store.data.bake(String(from.dropFirst(5))) { type = "bake"; id = k.id; label = k.name.isEmpty ? k.category : k.name }
        store.save(Lesson.make(text: text, loggedBy: by, recipe: store.data.recipe(recipeID), linkType: type, linkID: id, linkLabel: label))
        text = ""; recipeID = ""; from = ""
    }

    private func remove(_ l: Lesson) {
        store.remove(lesson: l.id)
        store.showToast("Lesson removed", undo: { store.restore(lesson: l.id) })
    }
}
