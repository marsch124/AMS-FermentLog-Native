import SwiftUI

/// Statistics over the jars (and, by the switch at the top, over the bakes).
struct InsightsScreen: View {
    @AppStorage("insightsView") private var view = "ferments"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                Picker("Show", selection: $view) {
                    Text("Ferments").tag("ferments")
                    Text("Bakes").tag("bakes")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("insights-switch")
                if view == "bakes" {
                    BakeInsightsScreen()
                } else {
                    InsightsFermentsView()
                }
            }
            .page()
        }
        .background(Theme.bg)
        .navigationTitle("Insights")
    }
}

/// The ferments view: headline numbers, a vegetable filter and the charts.
struct InsightsFermentsView: View {
    @EnvironmentObject var store: Store
    @State private var vegetable = ""

    var body: some View {
        let all = store.data.liveBatches
        let veg: String? = vegetable.isEmpty ? nil : vegetable
        let stats = Logic.summarizeStats(all, vegetable: veg)
        let pool = veg == nil ? all : all.filter { $0.vegetable == veg }
        let rec = Logic.recommendation(pool)
        let allVegs = Logic.summarizeStats(all).vegetables

        VStack(alignment: .leading, spacing: Theme.gap) {
            if allVegs.count > 1 {
                Picker("Show", selection: $vegetable) {
                    Text("All vegetables").tag("")
                    ForEach(allVegs, id: \.self) { Text($0).tag($0) }
                }
                .tint(Area.insights.color)
                .accessibilityIdentifier("insights-vegetable")
            }
            InsightsNumbers(stats: stats)
            if stats.ratingOverTime.count < 2 {
                Block(title: "Not enough yet", area: .insights) {
                    Text("Finish and rate at least two jars and your charts appear here.")
                        .foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("insights-empty")
                }
                InsightsRecommendation(rec: rec)
            } else {
                InsightsRecommendation(rec: rec)
                InsightsBest(stats: stats)
                InsightsCharts(stats: stats)
            }
        }
    }
}

/// Total jars, active now, success rate, average rating — compact, two columns.
struct InsightsNumbers: View {
    let stats: BatchStats
    var body: some View {
        Block(title: "Your jars", area: .insights) {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: Theme.tight) {
                Fact(name: "Jars", value: "\(stats.total)").accessibilityIdentifier("insights-total")
                Fact(name: "Active now", value: "\(stats.active)").accessibilityIdentifier("insights-active")
                Fact(name: "Success rate", value: stats.successRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—").accessibilityIdentifier("insights-success")
                Fact(name: "Average rating", value: stats.avgRating.map { String(format: "%.1f", $0) } ?? "—").accessibilityIdentifier("insights-average")
            }
        }
    }
}
