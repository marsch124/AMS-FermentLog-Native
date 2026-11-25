import SwiftUI

struct RecipeDetailScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let recipeID: String
    @State private var jarDraft = Logic.newBatch()
    @State private var bakeDraft = Logic.newBake()
    @State private var improveDraft = Logic.newRecipe()
    @State private var showJar = false
    @State private var showBake = false
    @State private var showImproved = false
    @State private var showImprove = false

    var body: some View {
        Group {
            if let r = store.data.recipe(recipeID) { content(r) } else { Color.clear }
        }
        .backdrop(.recipes)
        .onChange(of: store.data.recipe(recipeID) == nil) { _, gone in if gone { dismiss() } }
        .navigationTitle(store.data.recipe(recipeID)?.title ?? "Recipe")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: Route.recipeEdit(recipeID)) { Text("Edit") }.accessibilityIdentifier("recipe-edit")
            }
        }
    }

    private func content(_ r: Recipe) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                Hero(area: .recipes) {
                    FlowLayout(spacing: Theme.gap) {
                        Text(r.title).font(.title3.weight(.bold))
                        Pill(text: r.category, color: Area.recipes.color)
                    }
                    if !r.description.isEmpty { Text(r.description).font(.subheadline).foregroundStyle(Look.heroSoft) }
                    if !r.activeTime.isEmpty || !r.totalTime.isEmpty {
                        TileGrid(columns: 2) {
                            if !r.activeTime.isEmpty { Tile(label: "Hands-on", value: r.activeTime, area: .recipes) }
                            if !r.totalTime.isEmpty { Tile(label: "Start to finish", value: r.totalTime, area: .recipes) }
                        }
                    }
                    actions(r)
                }
                if !r.photos.isEmpty {
                    PhotoStrip(names: .constant(r.photos), editable: false, area: .recipes)
                }
                RecipeBlocks(recipe: r)
                lessons(r)
            }
            .page(.recipes)
        }
        .backdrop(.recipes)
        .navigationDestination(isPresented: $showJar) { JarFormScreen(batchID: nil, draft: jarDraft) }
        .navigationDestination(isPresented: $showBake) { BakeFormScreen(bakeID: nil, draft: bakeDraft) }
        .navigationDestination(isPresented: $showImproved) { RecipeFormScreen(recipeID: recipeID, draft: improveDraft) }
        .sheet(isPresented: $showImprove) {
            RecipeAISheet(title: "Improve with AI", prompt: "What should change?", button: "Improve the recipe", id: "recipe-improve") { text in
                improveDraft = try await AI.improveRecipe(r, request: text); showImproved = true
            }
        }
    }

    @ViewBuilder private func actions(_ r: Recipe) -> some View {
        FlowLayout(spacing: Theme.gap) {
            if r.category != "Sourdough" {
                Button("Start a jar from this recipe") {
                    jarDraft = Logic.batch(from: r, now: Date(), customSpices: store.data.settings.customSpices); showJar = true
                }
                .buttonStyle(PrimaryButtonStyle(area: .recipes)).accessibilityIdentifier("recipe-start-jar")
            }
            if r.category != "Vegetable ferment" {
                Button("Log a bake from this recipe") { bakeDraft = RecipeText.bakeDraft(from: r); showBake = true }
                    .buttonStyle(r.category == "Sourdough" ? AnyButtonStyle(PrimaryButtonStyle(area: .recipes)) : AnyButtonStyle(QuietButtonStyle(area: .recipes)))
                    .accessibilityIdentifier("recipe-log-bake")
            }
            Button("Duplicate") {
                let d = Logic.duplicateRecipe(r); store.save(d)
                NotificationCenter.default.post(name: .openRoute, object: Route.recipe(d.id))
            }
            .buttonStyle(QuietButtonStyle(area: .recipes)).accessibilityIdentifier("recipe-duplicate")
            ShareLink(item: RecipeText.summary(r), subject: Text(r.title)) { Text("Share") }
                .buttonStyle(QuietButtonStyle(area: .recipes)).accessibilityIdentifier("recipe-share")
            if AI.hasKey {
                Button("Improve with AI") { showImprove = true }
                    .buttonStyle(QuietButtonStyle(area: .recipes)).accessibilityIdentifier("recipe-improve-ai")
            }
        }
        if r.category != "Sourdough" {
            Text("The jar gets this recipe's steps as a list to tick off \u{2014} each tick is written into the jar's Timeline with the time.")
                .font(.caption).foregroundStyle(Look.heroSoft)
        }
    }

    @ViewBuilder private func lessons(_ r: Recipe) -> some View {
        let ls = store.data.liveLessons.filter { $0.recipeID == r.id }.sorted { $0.createdAt > $1.createdAt }
        if !ls.isEmpty {
            Block(title: "Lessons learned", area: .recipes) {
                ForEach(ls) { l in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.text).font(.subheadline)
                        let meta = [l.linkLabel, l.loggedBy, Human.day(Logic.isoDay(l.createdAt))].filter { !$0.isEmpty }.joined(separator: " \u{00b7} ")
                        Text(meta).font(.caption).foregroundStyle(Theme.muted)
                    }
                    .accessibilityIdentifier("recipe-lesson-\(l.id)")
                }
            }
        }
    }
}

/// Lets two different button styles sit in one expression.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ s: S) { make = { AnyView(s.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
