import SwiftUI

/// Ingredients, equipment, the numbered method and storage notes of a recipe (read only).
struct RecipeBlocks: View {
    let recipe: Recipe
    var body: some View {
        Block(title: "Ingredients", area: .recipes) { list(recipe.ingredients) }
        Block(title: "Equipment", area: .recipes) { list(recipe.equipment) }
        Block(title: "Method", area: .recipes) {
            if recipe.steps.isEmpty { Text("No steps yet.").font(.subheadline).foregroundStyle(Theme.muted) }
            ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { i, s in
                HStack(alignment: .firstTextBaseline, spacing: Theme.gap) {
                    Text("\(i + 1)").font(.body.weight(.bold)).foregroundStyle(Area.recipes.color).frame(minWidth: 20, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Theme.gap) {
                            Text(s.title).font(.body.weight(.bold))
                            if !s.time.isEmpty { Tag(text: s.time, color: Area.recipes.color) }
                        }
                        if !s.detail.isEmpty { Text(s.detail).font(.subheadline) }
                    }
                }
            }
        }
        if !recipe.storage.isEmpty {
            Block(title: "Storage and keeping", area: .recipes) { Text(recipe.storage).font(.subheadline) }
        }
    }
    @ViewBuilder private func list(_ items: [String]) -> some View {
        if items.isEmpty { Text("\u{2014}").foregroundStyle(Theme.muted) }
        ForEach(Array(items.enumerated()), id: \.offset) { _, i in Text(i).font(.subheadline) }
    }
}
