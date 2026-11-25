import SwiftUI

/// A small "Open this …" label that looks like the quiet button (the whole card is one link).
struct OpenLabel: View {
    let text: String
    let area: Area
    var body: some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(area.color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(area.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// "Recommended recipe" from the jars rated well, or a hint on how to get one.
struct InsightsRecommendation: View {
    let rec: Recommendation?
    var body: some View {
        if let rec {
            Hero(area: .insights) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Recommended recipe").font(.headline)
                    Text("learned from \(rec.count) of your best jars").font(.caption).foregroundStyle(Look.heroSoft)
                    Spacer(minLength: 0)
                }
                TileGrid(columns: 5, compact: 3) {
                    if let v = rec.vegetable { Tile(label: "Vegetable", value: v, area: .insights) }
                    if let b = rec.brine { Tile(label: "Brine", value: "\(trim(b))%", area: .insights) }
                    if let t = rec.tempC { Tile(label: "Room", value: "\(trim(t)) °C", area: .insights) }
                    if let d = rec.days { Tile(label: "Days", value: "about \(d)", area: .insights) }
                    if let l = rec.lid { Tile(label: "Lid", value: l, area: .insights) }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("insights-recommendation")
        } else {
            Block(title: "Recommended recipe", area: .insights) {
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
                    HStack(alignment: .center, spacing: Theme.gap) {
                        VStack(alignment: .leading, spacing: Theme.tight) {
                            HStack(spacing: 6) {
                                Text(b.title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                                Stars(value: stats.bestRating, area: .insights)
                            }
                            let brine = Logic.computeBrinePercent(salt: b.saltGrams, water: b.waterMl).map { String(format: "%.1f%% brine", $0) }
                            Text([b.vegetable, brine, b.roomTempC.map { "\(Int($0))°C" }, b.lidType.isEmpty ? nil : b.lidType]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                        OpenLabel(text: "Open this jar", area: .insights)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("insights-best-jar")
            }
        }
    }
}
