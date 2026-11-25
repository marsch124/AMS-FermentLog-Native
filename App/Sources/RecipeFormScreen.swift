import SwiftUI

struct RecipeFormScreen: View {
    let recipeID: String?
    var draft: Recipe? = nil
    init(recipeID: String?, draft: Recipe? = nil) { self.recipeID = recipeID; self.draft = draft }
    var body: some View {
        // LANE: lane Recipes: add / edit a recipe (draft = filled from a web page import)
        ContentUnavailableView("New recipe", systemImage: "hammer")
    }
}
