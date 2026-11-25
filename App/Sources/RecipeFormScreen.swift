import SwiftUI

struct RecipeFormScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let recipeID: String?
    var draft: Recipe? = nil
    init(recipeID: String?, draft: Recipe? = nil) { self.recipeID = recipeID; self.draft = draft }

    @State private var r = Logic.newRecipe()
    @State private var ingredients = ""
    @State private var equipment = ""
    @State private var loaded = false
    @State private var askDelete = false
    @State private var showAI = false

    var body: some View {
        Form {
            if AI.hasKey && recipeID == nil {
                Section {
                    Button("Describe it and let AI write the recipe") { showAI = true }
                        .buttonStyle(QuietButtonStyle(area: .recipes)).accessibilityIdentifier("recipe-ai-build")
                }
            }
            Section {
                TextField("Title", text: $r.title).accessibilityIdentifier("recipe-title")
                Picker("Category", selection: $r.category) {
                    ForEach(Logic.RECIPE_CATEGORIES, id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("recipe-category")
                TextField("Description", text: $r.description, axis: .vertical).lineLimit(1...5)
                    .accessibilityIdentifier("recipe-description")
            } header: { SectionHeading("Recipe", area: .recipes) }
            Section { PhotoStrip(names: $r.photos, area: .recipes) } header: { SectionHeading("Pictures", area: .recipes) }
            Section {
                TextEditor(text: $ingredients).frame(minHeight: 90).accessibilityIdentifier("recipe-ingredients")
            } header: { SectionHeading("Ingredients", area: .recipes) } footer: { Text("One per line").font(.caption) }
            Section {
                TextEditor(text: $equipment).frame(minHeight: 60).accessibilityIdentifier("recipe-equipment")
            } header: { SectionHeading("Equipment", area: .recipes) } footer: { Text("One per line").font(.caption) }
            Section {
                TextField("Hands-on time", text: $r.activeTime).accessibilityIdentifier("recipe-active-time")
                TextField("Total time", text: $r.totalTime).accessibilityIdentifier("recipe-total-time")
            } header: { SectionHeading("Time", area: .recipes) }
            RecipeStepsSection(steps: $r.steps)
            Section {
                TextField("Storage notes", text: $r.storage, axis: .vertical).lineLimit(1...5)
                    .accessibilityIdentifier("recipe-storage")
            } header: { SectionHeading("Storage and keeping", area: .recipes) }
            if let id = recipeID, store.data.recipe(id) != nil {
                Section {
                    Button("Delete this recipe") { askDelete = true }
                        .foregroundStyle(Theme.problem).buttonStyle(.borderless)
                        .accessibilityIdentifier("recipe-delete")
                }
            }
        }
        .formStyle(.grouped)
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
        .scrollContentBackground(.hidden).background(Theme.bg)
        .navigationTitle(recipeID == nil ? "New recipe" : "Edit recipe")
        .cancelSave(area: .recipes, canSave: !r.title.trimmingCharacters(in: .whitespaces).isEmpty,
                    onCancel: { dismiss() }, onSave: save)
        .confirmationDialog("Delete this recipe?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Delete this recipe", role: .destructive) { delete() }
            Button("Keep it", role: .cancel) {}
        }
        .sheet(isPresented: $showAI) {
            RecipeAISheet(title: "Write a recipe", prompt: "Describe the recipe you want.", button: "Write the recipe", id: "recipe-ai") { text in
                var made = try await AI.buildRecipe(from: text)
                made.id = r.id; made.photos = r.photos; made.createdAt = r.createdAt
                r = made; sync()
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let d = draft { r = d }
        else if let id = recipeID, let e = store.data.recipe(id) { r = e }
        if let id = recipeID { r.id = id }
        sync()
    }
    private func sync() { ingredients = r.ingredients.joined(separator: "\n"); equipment = r.equipment.joined(separator: "\n") }

    private func save() {
        var out = r
        out.title = r.title.trimmingCharacters(in: .whitespaces)
        out.ingredients = RecipeText.lines(ingredients)
        out.equipment = RecipeText.lines(equipment)
        out.steps = r.steps.filter { !($0.title + $0.detail + $0.time).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        out.modifiedAt = Date()
        store.save(out)
        let isNew = recipeID == nil
        dismiss()
        if isNew {
            Task { try? await Task.sleep(nanoseconds: 450_000_000); NotificationCenter.default.post(name: .openRoute, object: Route.recipe(out.id)) }
        }
    }

    private func delete() {
        let id = r.id
        store.remove(recipe: id)
        store.showToast("Recipe removed", undo: { store.restore(recipe: id) })
        dismiss()
    }
}
