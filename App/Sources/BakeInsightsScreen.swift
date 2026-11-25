import SwiftUI

/// Bake insights: headline numbers, best bake, charts, problems, and the lessons notebook.
struct BakeInsightsScreen: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let s = Logic.summarizeBakes(store.data.liveBakes)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                HStack(spacing: Theme.gap) {
                    kpi("\(s.total)", "bakes")
                    kpi("\(s.rated)", "rated")
                    kpi(s.avgOverall.map { String(format: "%.1f", $0) } ?? "\u{2014}", "average rating")
                }
                if let best = s.bestBake {
                    Block(title: "Best bake so far", area: .bakes) {
                        Text("\(best.name.isEmpty ? best.category : best.name) \(BakeText.stars(s.bestRating ?? 0))").font(.body.weight(.semibold))
                        Text([best.category, best.bakeDate, best.recipeTitle].filter { !$0.isEmpty }.joined(separator: " \u{00b7} "))
                            .font(.caption).foregroundStyle(Theme.muted)
                        NavigationLink(value: Route.bake(best.id)) { Text("Open this bake") }
                            .buttonStyle(QuietButtonStyle(area: .bakes)).accessibilityIdentifier("bake-insights-best")
                    }
                }
                BakeCharts(stats: s)
                if !s.problems.isEmpty {
                    Block(title: "How often each problem came up", area: .bakes) {
                        ForEach(s.problems, id: \.label) { p in
                            HStack(spacing: 6) {
                                Tag(text: p.label, color: Theme.problem)
                                Text("\(p.value) \(p.value == 1 ? "time" : "times")").font(.subheadline)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                BakeLessonsSection()
            }
            .page()
        }
        .background(Theme.bg)
        .navigationTitle("Bake insights")
    }

    private func kpi(_ n: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(n).font(.title2.weight(.bold)).foregroundStyle(Area.bakes.color)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
