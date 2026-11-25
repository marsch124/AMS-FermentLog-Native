import SwiftUI

/// Ingredients, equipment, the numbered method and storage notes of a recipe (read only).
struct RecipeBlocks: View {
    let recipe: Recipe
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var wide: Bool { sizeClass == .regular }
    #else
    private var wide: Bool { true }
    #endif

    var body: some View {
        lists
        Block(title: "Method", area: .recipes, note: "\(recipe.steps.count) step\(recipe.steps.count == 1 ? "" : "s")") {
            if recipe.steps.isEmpty { Text("No steps yet.").font(.subheadline).foregroundStyle(Theme.muted) }
            else {
                if recipe.steps.filter({ Human.minutes(from: $0.time) != nil }).count >= 2 { RecipeRibbon(steps: recipe.steps) }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { i, s in
                        stepRow(i, s, last: i == recipe.steps.count - 1)
                    }
                }
            }
        }
        if !recipe.storage.isEmpty {
            Block(title: "Storage and keeping", area: .recipes) { Text(recipe.storage).font(.subheadline) }
        }
    }

    @ViewBuilder private var lists: some View {
        let ing = Block(title: "Ingredients", area: .recipes) { ingredients(recipe.ingredients) }
        let eq = Block(title: "Equipment", area: .recipes) { equipment(recipe.equipment) }
        if wide && !recipe.ingredients.isEmpty && !recipe.equipment.isEmpty {
            HStack(alignment: .top, spacing: Theme.gap) {
                ing.frame(maxWidth: .infinity, alignment: .topLeading).layoutPriority(1)
                eq.frame(maxWidth: 280, alignment: .topLeading)
            }
        } else {
            ing
            eq
        }
    }

    private func stepRow(_ i: Int, _ s: RecipeStep, last: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.gap) {
            VStack(spacing: 2) {
                StepDot(number: i + 1, area: .recipes)
                if !last {
                    Rectangle().fill(Area.recipes.color.opacity(0.18)).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.gap) {
                    Text(s.title).font(.subheadline.weight(.bold))
                    if !s.time.isEmpty { Tag(text: s.time, color: Area.recipes.color) }
                }
                if !s.detail.isEmpty { Text(s.detail).font(.subheadline).foregroundStyle(Theme.muted) }
            }
            .padding(.bottom, last ? 0 : Theme.gap)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func ingredients(_ items: [String]) -> some View {
        if items.isEmpty { Text("\u{2014}").foregroundStyle(Theme.muted) }
        else {
            Grid(alignment: .topLeading, horizontalSpacing: Theme.gap, verticalSpacing: Theme.tight) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                    GridRow {
                        if let a = Human.amount(line) {
                            Text(a.amount).font(.subheadline.weight(.bold)).foregroundStyle(Area.recipes.color)
                                .gridColumnAlignment(.trailing)
                            Text(a.rest).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Color.clear.frame(width: 0, height: 0)
                            Text(line).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func equipment(_ items: [String]) -> some View {
        if items.isEmpty { Text("\u{2014}").foregroundStyle(Theme.muted) }
        ForEach(Array(items.enumerated()), id: \.offset) { _, i in Text(i).font(.subheadline) }
    }
}
