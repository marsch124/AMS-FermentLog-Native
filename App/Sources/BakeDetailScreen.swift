import SwiftUI

/// One bake: ratings, problems, photos, notes, lessons from it; Edit, Duplicate, Share.
struct BakeDetailScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let bakeID: String

    var body: some View {
        Group {
            if let bake = store.data.bake(bakeID) {
                content(bake)
            } else {
                Text("This bake is gone.").foregroundStyle(Theme.muted).padding()
                    .onAppear { dismiss() }
            }
        }
    }

    private func content(_ bake: Bake) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                Hero(area: .bakes) {
                    FlowLayout(spacing: Theme.gap) {
                        Text(bake.name.isEmpty ? bake.category : bake.name).font(.title3.weight(.bold))
                        Pill(text: bake.category, color: Area.bakes.color)
                    }
                    TileGrid(columns: 3, compact: 2) {
                        Tile(label: "Day", value: Human.day(bake.bakeDate), area: .bakes)
                        if !bake.recipeID.isEmpty, let r = store.data.recipe(bake.recipeID) {
                            NavigationLink(value: Route.recipe(bake.recipeID)) { Tile(label: "Recipe", value: r.title, area: .bakes) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("bake-recipe-link")
                        } else if !bake.recipeTitle.isEmpty {
                            Tile(label: "Recipe", value: bake.recipeTitle, area: .bakes)
                        }
                        if !bake.loggedBy.isEmpty { Tile(label: "Logged by", value: bake.loggedBy, area: .bakes) }
                    }
                }
                if !bake.photos.isEmpty { PhotoStrip(names: .constant(bake.photos), editable: false, area: .bakes) }
                Block(title: "How it turned out", area: .bakes) {
                    ratingRow("Crust", bake.ratings.crust.map(Double.init))
                    ratingRow("Crumb", bake.ratings.crumb.map(Double.init))
                    ratingRow("Flavour", bake.ratings.flavour.map(Double.init))
                    ratingRow("Overall", bake.ratings.overall.map(Double.init))
                    if bake.problems.isEmpty { Text("No problems.").font(.subheadline).foregroundStyle(Theme.muted) }
                    else { FlowLayout(spacing: 4) { ForEach(bake.problems, id: \.self) { Tag(text: $0, color: Theme.problem) } } }
                }
                if !bake.notes.isEmpty {
                    Block(title: "Notes", area: .bakes) { Text(bake.notes).font(.body) }
                }
                BakeLessonsOfBake(bake: bake)
                HStack(spacing: Theme.gap) {
                    Button("Duplicate") { duplicate(bake) }
                        .buttonStyle(QuietButtonStyle(area: .bakes)).accessibilityIdentifier("bake-duplicate")
                    ShareLink(item: BakeText.share(bake)) { Text("Share") }
                        .buttonStyle(QuietButtonStyle(area: .bakes)).accessibilityIdentifier("bake-share")
                }
            }
            .page(.bakes)
        }
        .backdrop(.bakes)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationTitle(bake.name.isEmpty ? bake.category : bake.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: Route.bakeEdit(bake.id)) { Text("Edit") }
                    .accessibilityIdentifier("bake-edit")
            }
        }
    }

    @ViewBuilder private func ratingRow(_ name: String, _ v: Double?) -> some View {
        if let v {
            BarRow(name: name, figure: BakeText.stars(v), share: min(1, max(0, v / 5)), area: .bakes)
        }
    }

    private func duplicate(_ bake: Bake) {
        let copy = Logic.duplicateBake(bake)
        store.save(copy)
        NotificationCenter.default.post(name: .openRoute, object: Route.bake(copy.id))
    }
}

enum BakeText {
    static func stars(_ v: Double) -> String {
        let n = max(0, min(5, Int(v.rounded())))
        return String(repeating: "\u{2605}", count: n) + String(repeating: "\u{2606}", count: 5 - n)
    }
    /// The same words the web app shares.
    static func share(_ b: Bake) -> String {
        var l = ["\(b.name.isEmpty ? "Bake" : b.name) (\(b.category))", "Date: \(b.bakeDate)"]
        if let r = Logic.overallBakeRating(b) { l.append("Rating: \(stars(r))") }
        if !b.problems.isEmpty { l.append("Problems: \(b.problems.joined(separator: ", "))") }
        if !b.notes.isEmpty { l.append("Notes: \(b.notes)") }
        return l.joined(separator: "\n")
    }
}
