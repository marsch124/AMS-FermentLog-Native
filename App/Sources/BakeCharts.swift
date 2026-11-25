import SwiftUI
import Charts

/// The bake charts; one friendly sentence when fewer than two bakes are rated.
struct BakeCharts: View {
    let stats: BakeStats

    var body: some View {
        if stats.rated < 2 {
            Text("Rate at least two bakes and the charts will show up here.")
                .font(.subheadline).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("bake-charts-empty")
        } else {
            Block(title: "Rating trend", area: .bakes, note: "oldest to newest") {
                RatingTrendChart(points: stats.ratingOverTime, area: .bakes, xName: "Bake number")
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
        Block(title: title, area: .bakes, note: "out of 5 stars") {
            VStack(alignment: .leading, spacing: Theme.gap) {
                ForEach(rows, id: \.0) { r in
                    BarRow(name: r.0, figure: String(format: "%.1f ★", r.1), share: r.1 / 5, area: .bakes)
                }
            }
        }
    }
}
