import SwiftUI
import Charts

/// All the charts of the ferments view.
struct InsightsCharts: View {
    let stats: BatchStats
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            InsightsScatter(title: "Rating and brine strength", xTitle: "Brine %", points: stats.ratingVsBrine, id: "brine")
            InsightsScatter(title: "Rating and room temperature", xTitle: "Temperature °C", points: stats.ratingVsTemp, id: "temperature")
            InsightsScatter(title: "Rating and days fermented", xTitle: "Days", points: stats.ratingVsDays, id: "days")
            InsightsTrend(points: stats.ratingOverTime)
            InsightsBars(title: "Average rating by vegetable", rows: stats.byVegetable, id: "vegetable")
            if !stats.byForm.isEmpty { InsightsBars(title: "Average rating by form", rows: stats.byForm, id: "form") }
            InsightsBars(title: "Average rating by lid", rows: stats.byLid, id: "lid")
            InsightsProblems(rows: stats.problems)
        }
    }
}

private extension View {
    func ratingAxis() -> some View {
        chartYScale(domain: 0...5)
            .chartYAxis { AxisMarks(values: [1, 2, 3, 4, 5]) }
            .chartYAxisLabel("Rating")
    }
}

struct InsightsScatter: View {
    let title: String, xTitle: String, points: [XYPoint], id: String
    var body: some View {
        Block(title: title, area: .insights) {
            if points.isEmpty {
                Text("Nothing to show yet.").foregroundStyle(Theme.muted)
            } else {
                Chart(Array(points.enumerated()), id: \.offset) { _, p in
                    PointMark(x: .value(xTitle, p.x), y: .value("Rating", p.y))
                        .foregroundStyle(Area.insights.color)
                }
                .ratingAxis()
                .chartXAxisLabel(xTitle)
                .frame(height: 160)
            }
        }
        .accessibilityIdentifier("insights-chart-\(id)")
    }
}

struct InsightsTrend: View {
    let points: [XYPoint]
    var body: some View {
        Block(title: "Rating over your attempts", area: .insights) {
            Chart(Array(points.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Attempt", p.x), y: .value("Rating", p.y))
                    .foregroundStyle(Area.insights.color)
                PointMark(x: .value("Attempt", p.x), y: .value("Rating", p.y))
                    .foregroundStyle(Area.insights.color)
            }
            .ratingAxis()
            .chartXAxisLabel("Attempt, oldest to newest")
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
            .frame(height: 160)
        }
        .accessibilityIdentifier("insights-chart-trend")
    }
}

/// Horizontal bars; each row's name carries its value, written beside it on the left.
struct InsightsBars: View {
    let title: String, rows: [LabelValue], id: String
    var body: some View {
        Block(title: title, area: .insights) {
            if rows.isEmpty {
                Text("Nothing to show yet.").foregroundStyle(Theme.muted)
            } else {
                let named = rows.map { (name: "\($0.label)  \(String(format: "%.1f", $0.value))", value: $0.value) }
                Chart(named, id: \.name) { r in
                    BarMark(x: .value("Rating", r.value), y: .value("Name", r.name))
                        .foregroundStyle(Area.insights.color)
                }
                .chartXScale(domain: 0...5)
                .chartXAxisLabel("Average rating")
                .frame(height: max(160, CGFloat(rows.count) * 30))
            }
        }
        .accessibilityIdentifier("insights-chart-\(id)")
    }
}

struct InsightsProblems: View {
    let rows: [LabelCount]
    var body: some View {
        Block(title: "Problems that came up", area: .insights) {
            if rows.isEmpty {
                Text("No problems recorded.").foregroundStyle(Theme.muted)
            } else {
                let named = rows.map { (name: "\($0.label)  \($0.value)", value: $0.value) }
                Chart(named, id: \.name) { r in
                    BarMark(x: .value("Jars", r.value), y: .value("Problem", r.name))
                        .foregroundStyle(Theme.problem)
                }
                .chartXAxisLabel("Number of jars")
                .frame(height: max(160, CGFloat(rows.count) * 30))
            }
        }
        .accessibilityIdentifier("insights-chart-problems")
    }
}
