import SwiftUI
import Charts

/// The three bake charts, each about 160 points tall; one friendly sentence when fewer than two bakes are rated.
struct BakeCharts: View {
    let stats: BakeStats

    var body: some View {
        if stats.rated < 2 {
            Text("Rate at least two bakes and the charts will show up here.")
                .font(.subheadline).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("bake-charts-empty")
        } else {
            Block(title: "Rating trend, oldest to newest", area: .bakes) {
                Chart(stats.ratingOverTime, id: \.x) { p in
                    LineMark(x: .value("Bake number", p.x), y: .value("Rating", p.y)).foregroundStyle(Area.bakes.color)
                    PointMark(x: .value("Bake number", p.x), y: .value("Rating", p.y)).foregroundStyle(Area.bakes.color)
                }
                .chartYScale(domain: 0...5)
                .chartXScale(domain: 0.5...(Double(max(2, stats.ratingOverTime.count)) + 0.5))   // half a bake of air at both ends, so the first and last number show
                .chartXAxis { AxisMarks(values: BakeCharts.wholeMarks(stats.ratingOverTime.count)) }   // whole bakes, never "1,5"
                .chartXAxisLabel("Bake number (1 is the oldest)")
                .chartYAxisLabel("Stars")
                .frame(height: 160)
            }
            average("Average rating by recipe", stats.byRecipe.map { ($0.label.isEmpty ? "No recipe" : $0.label, $0.value) })
            average("Average rating by category", stats.byCategory.map { ($0.label.isEmpty ? "Other" : $0.label, $0.value) })
        }
    }

    /// 1, 2, 3 … up to the number of bakes; at most about eight marks.
    static func wholeMarks(_ count: Int) -> [Int] {
        let n = max(2, count)
        return Array(stride(from: 1, through: n, by: max(1, Int((Double(n) / 8).rounded(.up)))))
    }

    private func average(_ title: String, _ rows: [(String, Double)]) -> some View {
        Block(title: title, area: .bakes) {
            Chart(rows, id: \.0) { r in
                BarMark(x: .value("Average stars", r.1), y: .value("Name", r.0)).foregroundStyle(Area.bakes.color)
            }
            .chartXScale(domain: 0...5)
            .chartXAxisLabel("Average stars")
            .frame(height: 160)
        }
    }
}
