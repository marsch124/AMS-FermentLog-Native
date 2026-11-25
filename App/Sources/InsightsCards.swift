import SwiftUI

/// "Recommended recipe" from the jars rated well, or a hint on how to get one.
struct InsightsRecommendation: View {
    let rec: Recommendation?
    var body: some View {
        Block(title: "Recommended recipe", area: .insights) {
            if let rec {
                VStack(alignment: .leading, spacing: Theme.tight) {
                    if let v = rec.vegetable { Fact(name: "Vegetable", value: v) }
                    if let b = rec.brine { Fact(name: "Brine", value: "\(trim(b))%") }
                    if let t = rec.tempC { Fact(name: "Temperature", value: "\(trim(t))°C") }
                    if let d = rec.days { Fact(name: "Days", value: "about \(d)") }
                    if let l = rec.lid { Fact(name: "Lid", value: l) }
                    Text("Learned from \(rec.count) of your best jars")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .accessibilityIdentifier("insights-recommendation")
            } else {
                Text("Once two jars are rated 4 stars or more, a recipe learned from them appears here.")
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("insights-recommendation-hint")
            }
        }
    }
    private func trim(_ d: Double) -> String { d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d) }
}

/// The best-rated jar, with a link to it.
struct InsightsBest: View {
    let stats: BatchStats
    var body: some View {
        if let b = stats.bestBatch {
            Block(title: "Best jar so far", area: .insights) {
                NavigationLink(value: Route.jar(b.id)) {
                    VStack(alignment: .leading, spacing: Theme.tight) {
                        HStack(spacing: 6) {
                            Text(b.title).fontWeight(.semibold).foregroundStyle(Theme.ink)
                            Stars(value: stats.bestRating, area: .insights)
                        }
                        let brine = Logic.computeBrinePercent(salt: b.saltGrams, water: b.waterMl).map { String(format: "%.1f%% brine", $0) }
                        Text([b.vegetable, brine, b.roomTempC.map { "\(Int($0))°C" }, b.lidType.isEmpty ? nil : b.lidType]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(Theme.muted)
                        Text("Open this jar").font(.subheadline.weight(.semibold)).foregroundStyle(Area.insights.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("insights-best-jar")
            }
        }
    }
}
