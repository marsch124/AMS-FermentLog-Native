import SwiftUI

/// The Bakes list (the Home tab's second view): newest bake first, one full-colour button to log a bake.
struct BakesScreen: View {
    @EnvironmentObject var store: Store

    private var bakes: [Bake] {
        store.data.liveBakes.sorted { ($0.bakeDate, $0.createdAt) > ($1.bakeDate, $1.createdAt) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                if bakes.isEmpty {
                    Text("No bakes yet. Log your first loaf and rate how it turned out.")
                        .foregroundStyle(Theme.muted)
                        .padding(.top, Theme.gap)
                        .accessibilityIdentifier("bakes-empty")
                    NavigationLink(value: Route.bakeNew) { Text("Log a bake") }
                        .buttonStyle(PrimaryButtonStyle(area: .bakes))
                        .accessibilityIdentifier("bakes-log")
                } else {
                    NavigationLink(value: Route.bakeNew) { Text("Log a bake") }
                        .buttonStyle(PrimaryButtonStyle(area: .bakes))
                        .accessibilityIdentifier("bakes-log")
                    ForEach(bakes) { BakeRow(bake: $0) }
                }
                NavigationLink(value: Route.bakeInsights) { Text("Bake insights and lessons") }
                    .buttonStyle(QuietButtonStyle(area: .bakes))
                    .accessibilityIdentifier("bakes-insights")
            }
            .page()
        }
        .background(Theme.bg)
    }
}

/// One bake in the list: picture or bread mark, name, category, date, recipe, stars, problems.
struct BakeRow: View {
    @EnvironmentObject var store: Store
    let bake: Bake

    var body: some View {
        NavigationLink(value: Route.bake(bake.id)) {
            HStack(alignment: .top, spacing: Theme.gap) {
                thumb
                VStack(alignment: .leading, spacing: Theme.tight) {
                    Text(bake.name.isEmpty ? bake.category : bake.name)
                        .font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    HStack(spacing: Theme.gap) {
                        Pill(text: bake.category, color: Area.bakes.color)
                        Text(bake.bakeDate).font(.caption).foregroundStyle(Theme.muted)
                    }
                    if !bake.recipeTitle.isEmpty {
                        Text(bake.recipeTitle).font(.caption).foregroundStyle(Theme.muted)
                    }
                    if let r = Logic.overallBakeRating(bake) { Stars(value: r, area: .bakes).font(.subheadline) }
                    else { Text("Not rated yet").font(.caption).foregroundStyle(Theme.muted) }
                    if !bake.problems.isEmpty {
                        FlowLayout(spacing: 4) { ForEach(bake.problems, id: \.self) { Tag(text: $0, color: Theme.problem) } }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bake-row-\(bake.id)")
    }

    @ViewBuilder private var thumb: some View {
        if let first = bake.photos.first {
            PhotoImage(url: store.photoURL(first)).frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Mark(.bread).foregroundStyle(Area.bakes.color).padding(12).frame(width: 56, height: 56)
                .background(Area.bakes.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
