import SwiftUI

struct BakeFormScreen: View {
    let bakeID: String?
    var draft: Bake? = nil
    init(bakeID: String?, draft: Bake? = nil) { self.bakeID = bakeID; self.draft = draft }
    var body: some View {
        // LANE: lane Bakes: add / edit a bake (draft = prefilled from a recipe)
        ContentUnavailableView("New bake", systemImage: "hammer")
    }
}
