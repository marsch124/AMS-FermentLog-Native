import SwiftUI

/// Bake insights: headline numbers, best bake, charts, problems, and the lessons notebook.
struct BakeInsightsScreen: View {
    @EnvironmentObject var store: Store

    /// True inside the Insights page, which already scrolls: then this draws its content only, not a second scrolling page inside the first.
    var embedded = false

    var body: some View {
        let s = Logic.summarizeBakes(store.data.liveBakes)
        if embedded {
            content(s)
        } else {
            ScrollView { content(s).page(.bakes) }
                .backdrop(.bakes)
                .navigationTitle("Bake insights")
        }
    }

    private func content(_ s: BakeStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            TileGrid(columns: 3, compact: 3) {
                StatTile(value: "\(s.total)", label: "Bakes", area: .bakes, filled: true)
                    .accessibilityIdentifier("bake-insights-total")
                StatTile(value: "\(s.rated)", label: "Rated", area: .bakes)
                    .accessibilityIdentifier("bake-insights-rated")
                StatTile(value: s.avgOverall.map { String(format: "%.1f ★", $0) } ?? "\u{2014}", label: "Average rating", area: .bakes)
                    .accessibilityIdentifier("bake-insights-average")
            }
            if let best = s.bestBake {
                Block(title: "Best bake so far", area: .bakes) {
                    NavigationLink(value: Route.bake(best.id)) {
                        HStack(alignment: .center, spacing: Theme.gap) {
                            VStack(alignment: .leading, spacing: Theme.tight) {
                                HStack(spacing: 6) {
                                    Text(best.name.isEmpty ? best.category : best.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                                    Stars(value: s.bestRating, area: .bakes)
                                }
                                Text([best.category, Human.day(best.bakeDate), best.recipeTitle].filter { !$0.isEmpty }.joined(separator: " \u{00b7} "))
                                    .font(.subheadline).foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 0)
                            OpenLabel(text: "Open this bake", area: .bakes)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bake-insights-best")
                }
            }
            BakeCharts(stats: s)
            if !s.problems.isEmpty {
                let top = Double(max(1, s.problems.map(\.value).max() ?? 1))
                Block(title: "How often each problem came up", area: .bakes) {
                    VStack(alignment: .leading, spacing: Theme.gap) {
                        ForEach(s.problems, id: \.label) { p in
                            BarRow(name: p.label, figure: p.value == 1 ? "1 time" : "\(p.value) times",
                                   share: Double(p.value) / top, area: .bakes, color: Theme.problem)
                        }
                    }
                }
            }
            BakeLessonsSection()
        }
    }
}
