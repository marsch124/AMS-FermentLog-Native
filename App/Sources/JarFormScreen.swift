import SwiftUI

struct JarFormScreen: View {
    let batchID: String?
    var draft: Batch? = nil
    init(batchID: String?, draft: Batch? = nil) { self.batchID = batchID; self.draft = draft }
    var body: some View {
        // LANE: lane Jars: add / edit a jar (nil batchID = new; draft = a jar prefilled from a recipe or preset)
        ContentUnavailableView("New jar", systemImage: "hammer")
    }
}
