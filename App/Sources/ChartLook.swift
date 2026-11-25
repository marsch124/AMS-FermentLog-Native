import SwiftUI
import Charts

/// Shared calm chart styling for ferment and bake insights.
enum ChartLook {
    static func number(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

/// A filled round dot with a thin card-coloured edge.
struct ChartDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color).frame(width: 12, height: 12)
            .overlay(Circle().stroke(Theme.surface, lineWidth: 2.5))
    }
}

extension View {
    /// Rating axis on the left: 5 ★ … 1, hairline grid, no ticks, no axis line.
    func calmRatingAxis() -> some View {
        chartYScale(domain: 0.5...5.5)
            .chartYAxis {
                AxisMarks(position: .leading, values: [1.0, 2.0, 3.0, 4.0, 5.0]) { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.line)
                    AxisValueLabel(anchor: .trailing) {
                        if let d = v.as(Double.self) {
                            Text(d == 5 ? "5 ★" : "\(Int(d))").font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
    }

    /// X axis without grid lines; labels carry the unit ("2%", "20 °C", "14 d"); whole numbers when whole.
    func calmXAxis(unit: String = "", values: AxisMarkValues = .automatic(desiredCount: 5)) -> some View {
        chartXAxis {
            AxisMarks(values: values) { v in
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text(ChartLook.number(d) + unit).font(.caption2).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }

    /// Same, with whole-number marks only (attempt / bake numbers).
    func calmWholeXAxis(_ marks: [Int]) -> some View {
        chartXAxis {
            AxisMarks(values: marks.map(Double.init)) { v in
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text("\(Int(d))").font(.caption2).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
    }
}

/// The rating-over-time chart, shared by ferments (attempts) and bakes (bake numbers).
struct RatingTrendChart: View {
    let points: [XYPoint]
    let area: Area
    let xName: String
    var body: some View {
        let count = max(2, points.count)
        let step = max(1, Int((Double(count) / 8).rounded(.up)))
        let marks = Array(stride(from: 1, through: count, by: step))
        Chart(Array(points.enumerated()), id: \.offset) { _, p in
            AreaMark(x: .value(xName, p.x), yStart: .value("Base", 0.5), yEnd: .value("Rating", p.y))
                .foregroundStyle(area.color.opacity(0.10))
                .interpolationMethod(.monotone)
            LineMark(x: .value(xName, p.x), y: .value("Rating", p.y))
                .foregroundStyle(area.color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            PointMark(x: .value(xName, p.x), y: .value("Rating", p.y))
                .symbol { ChartDot(color: area.color) }
        }
        .calmRatingAxis()
        .chartXScale(domain: 0.5...(Double(count) + 0.5))
        .calmWholeXAxis(marks)
        .frame(height: 150)
    }
}
