import SwiftUI

/// Statistics over the jars (and, by the switch at the top, over the bakes).
struct InsightsScreen: View {
    @EnvironmentObject var store: Store
    @AppStorage("insightsView") private var view = "ferments"
    @State private var vegetable = ""

    var body: some View {
        let allVegs = Logic.summarizeStats(store.data.liveBatches).vegetables
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                HStack(spacing: Theme.gap) {
                    Segments(selection: $view,
                             options: [(value: "ferments", title: "Ferments"), (value: "bakes", title: "Bakes")],
                             area: view == "bakes" ? .bakes : .insights, id: "insights-switch")
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("insights-switch")
                    if view != "bakes" && allVegs.count > 1 {
                        Picker("Vegetable", selection: $vegetable) {
                            Text("All vegetables").tag("")
                            ForEach(allVegs, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(Area.insights.color)
                        .accessibilityIdentifier("insights-vegetable")
                    }
                    Spacer(minLength: 0)
                }
                if view == "bakes" {
                    BakeInsightsScreen(embedded: true)
                } else {
                    InsightsFermentsView(vegetable: vegetable)
                }
            }
            .page(view == "bakes" ? .bakes : .insights)
        }
        .backdrop(view == "bakes" ? .bakes : .insights)
        .navigationTitle("Insights")
    }
}

/// The ferments view: headline numbers, a vegetable filter and the charts.
struct InsightsFermentsView: View {
    @EnvironmentObject var store: Store
    let vegetable: String

    var body: some View {
        let all = store.data.liveBatches
        let veg: String? = vegetable.isEmpty ? nil : vegetable
        let stats = Logic.summarizeStats(all, vegetable: veg)
        let pool = veg == nil ? all : all.filter { $0.vegetable == veg }
        let rec = Logic.recommendation(pool)

        VStack(alignment: .leading, spacing: Theme.gap) {
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

/// Total jars, active now, success rate, average rating.
struct InsightsNumbers: View {
    let stats: BatchStats
    var body: some View {
        TileGrid(columns: 4, compact: 2) {
            StatTile(value: "\(stats.total)", label: "Jars", area: .insights, filled: true)
                .accessibilityIdentifier("insights-total")
            StatTile(value: "\(stats.active)", label: "Active now", area: .insights)
                .accessibilityIdentifier("insights-active")
            StatTile(value: stats.successRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", label: "Success", area: .insights, ring: stats.successRate)
                .accessibilityIdentifier("insights-success")
            StatTile(value: stats.avgRating.map { String(format: "%.1f ★", $0) } ?? "—", label: "Average rating", area: .insights)
                .accessibilityIdentifier("insights-average")
        }
    }
}
