import SwiftUI

struct BakeDetailScreen: View {
    let bakeID: String
    var body: some View {
        // LANE: lane Bakes: one bake — ratings, problems, photos, notes
        ContentUnavailableView("Bake", systemImage: "hammer")
    }
}
