import SwiftUI

struct RecipesScreen: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let recipes = store.data.liveRecipes.sorted { $0.modifiedAt > $1.modifiedAt }
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                if recipes.isEmpty {
                    empty
                } else {
                    NavigationLink(value: Route.recipeNew) { Text("New recipe") }
                        .buttonStyle(PrimaryButtonStyle(area: .recipes))
                        .accessibilityIdentifier("recipes-new")
                    ForEach(recipes) { r in
                        NavigationLink(value: Route.recipe(r.id)) { RecipeRow(recipe: r) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("recipe-row-\(r.id)")
                    }
                }
            }
            .page()
        }
        .background(Theme.bg)
        .navigationTitle("Recipes")
    }

    private var empty: some View {
        VStack(spacing: Theme.gap) {
            Mark(.book).frame(width: 44, height: 44).foregroundStyle(Area.recipes.color)
            Text("No recipes yet. Keep your fermenting and baking recipes here: ingredients, timed steps and storage notes.")
                .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            NavigationLink(value: Route.recipeNew) { Text("New recipe") }
                .buttonStyle(PrimaryButtonStyle(area: .recipes))
                .accessibilityIdentifier("recipes-new")
            Button("Add the sourdough example") { store.save(Logic.sampleSourdoughRecipe()) }
                .buttonStyle(QuietButtonStyle(area: .recipes))
                .accessibilityIdentifier("recipes-add-example")
        }
        .frame(maxWidth: .infinity).padding(.top, 24)
    }
}

/// One recipe in the list: picture or the book mark, title, category pill, times and step count.
struct RecipeRow: View {
    @EnvironmentObject var store: Store
    let recipe: Recipe
    var body: some View {
        HStack(spacing: Theme.gap) {
            Group {
                if let p = recipe.photos.first {
                    PhotoImage(url: store.photoURL(p))
                } else {
                    Area.recipes.color.opacity(0.14)
                        .overlay { Mark(.book).frame(width: 24, height: 24).foregroundStyle(Area.recipes.color) }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: Theme.tight) {
                Text(recipe.title.isEmpty ? "Untitled recipe" : recipe.title)
                    .font(.body.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(2)
                HStack(spacing: Theme.gap) {
                    Pill(text: recipe.category, color: Area.recipes.color)
                    if !recipe.activeTime.isEmpty { Text("Hands-on \(recipe.activeTime)") }
                    if !recipe.totalTime.isEmpty { Text("Total \(recipe.totalTime)") }
                    if !recipe.steps.isEmpty { Text("\(recipe.steps.count) step\(recipe.steps.count == 1 ? "" : "s")") }
                }
                .font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
    }
}
