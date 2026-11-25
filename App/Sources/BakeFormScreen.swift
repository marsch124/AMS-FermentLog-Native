import SwiftUI

/// Log a new bake (optionally from a prefilled draft) or change one. Nothing is saved before Save.
struct BakeFormScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let bakeID: String?
    var draft: Bake? = nil
    init(bakeID: String?, draft: Bake? = nil) { self.bakeID = bakeID; self.draft = draft }

    @State private var bake: Bake?
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if bake != nil { form } else { Color.clear }
        }
        .navigationTitle(bakeID == nil ? "Log a bake" : "Edit bake")
        .onAppear(perform: load)
    }

    private func load() {
        guard bake == nil else { return }
        if let id = bakeID, let existing = store.data.bake(id) { bake = existing }
        else if bakeID == nil {
            var b = draft ?? Logic.newBake()
            if b.loggedBy.isEmpty { b.loggedBy = store.data.settings.activePerson }
            bake = b
        } else { dismiss() }
    }

    private var form: some View {
        let b = Binding<Bake>(get: { bake ?? Bake() }, set: { bake = $0 })
        let recipes = store.data.liveRecipes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return Form {
            if bakeID == nil && AI.hasKey { BakeAIFill(bake: b, recipes: recipes) }
            Section {
                TextField("Name", text: b.name).accessibilityIdentifier("bake-name")
                Picker("Category", selection: b.category) {
                    ForEach(Logic.BAKE_CATEGORIES, id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("bake-category")
                DatePicker("Date", selection: BakeDate.binding(b.bakeDate), displayedComponents: .date)
                    .accessibilityIdentifier("bake-date")
                Picker("Recipe", selection: Binding(get: { b.wrappedValue.recipeID }, set: { pick($0, recipes, b) })) {
                    Text("None").tag("")
                    ForEach(recipes) { Text($0.title.isEmpty ? "Untitled" : $0.title).tag($0.id) }
                }.accessibilityIdentifier("bake-recipe")
                LoggedByPicker(name: b.loggedBy)
            }
            Section("Photos") { PhotoStrip(names: b.photos, area: .bakes) }
            Section("How it turned out") {
                StarRating(label: "Crust", value: b.ratings.crust, area: .bakes, id: "bake-stars-crust")
                StarRating(label: "Crumb", value: b.ratings.crumb, area: .bakes, id: "bake-stars-crumb")
                StarRating(label: "Flavour", value: b.ratings.flavour, area: .bakes, id: "bake-stars-flavour")
                StarRating(label: "Overall", value: b.ratings.overall, area: .bakes, id: "bake-stars-overall")
                Text("Tap a star to rate; tap the same star again to clear it.").font(.caption).foregroundStyle(Theme.muted)
            }
            Section("Problems") {
                ChipPicker(options: Logic.BAKE_PROBLEMS, selection: b.problems, area: .bakes, id: "bake-problem")
            }
            Section("Notes") {
                TextField("Notes", text: b.notes, axis: .vertical).lineLimit(2...8).accessibilityIdentifier("bake-notes")
            }
            if bakeID != nil {
                Section {
                    Button("Delete this bake", role: .destructive) { confirmDelete = true }
                        .accessibilityIdentifier("bake-delete")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Area.bakes.color)
        .cancelSave(area: .bakes, onCancel: { dismiss() }, onSave: save)
        .confirmationDialog("Delete this bake?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete this bake", role: .destructive) { delete() }
            Button("Keep it", role: .cancel) {}
        }
    }

    private func pick(_ id: String, _ recipes: [Recipe], _ b: Binding<Bake>) {
        b.wrappedValue.recipeID = id
        b.wrappedValue.recipeTitle = recipes.first { $0.id == id }?.title ?? ""
    }

    private func save() {
        guard var out = bake else { return }
        out.modifiedAt = Date()
        store.save(out)
        let isNew = bakeID == nil
        dismiss()
        if isNew { NotificationCenter.default.post(name: .openRoute, object: Route.bake(out.id)) }
    }

    private func delete() {
        guard let id = bakeID else { return }
        store.remove(bake: id)
        store.showToast("Bake removed", undo: { store.restore(bake: id) })
        dismiss()
    }
}

/// "yyyy-MM-dd" text <-> Date.
enum BakeDate {
    static func binding(_ s: Binding<String>) -> Binding<Date> {
        Binding(get: { date(s.wrappedValue) }, set: { s.wrappedValue = Logic.isoDay($0) })
    }
    static func date(_ s: String) -> Date {
        let p = s.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return Date() }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) ?? Date()
    }
}

/// "Describe the bake and let AI fill this in" — only when a key is set.
struct BakeAIFill: View {
    @Binding var bake: Bake
    let recipes: [Recipe]
    @State private var text = ""
    @State private var busy = false
    @State private var message = ""

    var body: some View {
        Section("Describe the bake and let AI fill this in") {
            TextField("e.g. Sourdough boule yesterday, crust 4, crumb a bit dense", text: $text, axis: .vertical)
                .lineLimit(2...5).accessibilityIdentifier("bake-ai-text")
            Button(busy ? "Working…" : "Fill this in") { run() }
                .buttonStyle(QuietButtonStyle(area: .bakes))
                .disabled(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("bake-ai-fill")
            if !message.isEmpty { Text(message).font(.caption).foregroundStyle(Theme.problem) }
        }
    }

    private func run() {
        busy = true; message = ""
        Task {
            do {
                let r = try await AI.buildBake(from: text, recipes: recipes)
                if !r.name.isEmpty { bake.name = r.name }
                bake.category = r.category
                if !r.bakeDate.isEmpty { bake.bakeDate = r.bakeDate }
                bake.recipeID = r.recipeID; bake.recipeTitle = r.recipeTitle
                bake.ratings = r.ratings; bake.problems = r.problems
                if !r.notes.isEmpty { bake.notes = r.notes }
            } catch { message = error.localizedDescription }
            busy = false
        }
    }
}
