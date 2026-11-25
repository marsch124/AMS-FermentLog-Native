import SwiftUI
import Charts

/// All the charts of the ferments view.
struct InsightsCharts: View {
    let stats: BatchStats
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            InsightsScatter(title: "Rating and brine strength", xTitle: "Brine", unit: "%", points: stats.ratingVsBrine, id: "brine")
            InsightsScatter(title: "Rating and room temperature", xTitle: "Temperature", unit: " °C", points: stats.ratingVsTemp, id: "temperature")
            InsightsScatter(title: "Rating and days fermented", xTitle: "Days", unit: " d", points: stats.ratingVsDays, id: "days")
            InsightsTrend(points: stats.ratingOverTime)
            InsightsBars(title: "Average rating by vegetable", rows: stats.byVegetable, id: "vegetable", note: "out of 5 stars")
            TileGrid(columns: 2, compact: 1) {
                if !stats.byForm.isEmpty { InsightsBars(title: "Average rating by form", rows: stats.byForm, id: "form") }
                InsightsBars(title: "Average rating by lid", rows: stats.byLid, id: "lid")
            }
            InsightsProblems(rows: stats.problems)
        }
    }
}

struct InsightsScatter: View {
    let title: String, xTitle: String, unit: String, points: [XYPoint], id: String
    var body: some View {
        Block(title: title, area: .insights, note: id == "brine" ? "each dot is one jar \u{00b7} shaded = the usual 2–3%" : "each dot is one jar") {
            if points.isEmpty {
                Text("Nothing to show yet.").foregroundStyle(Theme.muted)
            } else {
                let isBrine = id == "brine"
                let hi = points.map(\.x).max() ?? 0
                let lo = points.map(\.x).min() ?? 0
                let pad = max(0.5, (hi - lo) * 0.08)
                Chart {
                    if isBrine {
                        RectangleMark(xStart: .value("From", Logic.BRINE_MIN), xEnd: .value("To", Logic.BRINE_MAX),
                                      yStart: .value("Low", 0.5), yEnd: .value("High", 5.5))
                            .foregroundStyle(Area.insights.color.opacity(0.12))   // what it means stands beside the heading (under the chart it ran into the 1% … 2% labels)
                    }
                    ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                        PointMark(x: .value(xTitle, p.x), y: .value("Rating", p.y))
                            .symbol { ChartDot(color: Area.insights.color) }
                    }
                }
                .calmRatingAxis()
                .chartXScale(domain: isBrine ? 0...max(3.2, hi * 1.05) : (lo - pad)...(hi + pad))
                .calmXAxis(unit: unit)
                .frame(height: 150)
            }
        }
        .accessibilityIdentifier("insights-chart-\(id)")
    }
}

struct InsightsTrend: View {
    let points: [XYPoint]
    var body: some View {
        Block(title: "Rating over your attempts", area: .insights, note: "oldest to newest") {
            RatingTrendChart(points: points, area: .insights, xName: "Attempt")
        }
        .accessibilityIdentifier("insights-chart-trend")
    }
}

/// Slim bars; each row's name carries its value, written beside it on the left.
struct InsightsBars: View {
    let title: String, rows: [LabelValue], id: String
    var note: String?
    var body: some View {
        Block(title: title, area: .insights, note: note) {
            if rows.isEmpty {
                Text("Nothing to show yet.").foregroundStyle(Theme.muted)
            } else {
                VStack(alignment: .leading, spacing: Theme.gap) {
                    ForEach(rows, id: \.label) { r in
                        BarRow(name: r.label, figure: String(format: "%.1f ★", r.value), share: r.value / 5, area: .insights)
                    }
                }
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
                let top = Double(max(1, rows.map(\.value).max() ?? 1))
                VStack(alignment: .leading, spacing: Theme.gap) {
                    ForEach(rows, id: \.label) { r in
                        BarRow(name: r.label, figure: r.value == 1 ? "1 jar" : "\(r.value) jars",
                               share: Double(r.value) / top, area: .insights, color: Theme.problem)
                    }
                }
            }
        }
        .accessibilityIdentifier("insights-chart-problems")
    }
}
